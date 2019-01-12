require 'fileutils'
require 'thread'
require 'openssl'
require 'open-uri'
require 'nokogiri'
require 'selenium-webdriver'


module DocTruyen
    S_OPTIONS = Selenium::WebDriver::Chrome::Options.new(args: ['headless'])

    class Chapter
        attr_reader :name
        def initialize url
            # Get chapter name from url
            @url = url
            @name = url.split('/')[-1].split('-')[0..-2].join('-')
            @scraper_driver = Selenium::WebDriver.for(:chrome, options: S_OPTIONS)
            
            @scraper_driver.get @url
            div_reader = @scraper_driver.find_element(:id, 'reader')
            reader_xml = @scraper_driver.execute_script('return arguments[0].innerHTML', div_reader)
            doc = Nokogiri::XML reader_xml
            @image_urls = doc.xpath('//img/@src').map(&:content)
        end

        def download base_dir, conc, callback
            # Prepare the directory
            dirname = "#{base_dir}/#{@name}"
            FileUtils.mkdir_p dirname unless File.directory? dirname

            idx = 0
            threads = []
            semaphore = Mutex.new
            conc = @image_urls.count if conc > @image_urls.count
            conc.times do |th_idx|
                threads << Thread.new do |th; i|
                    lambda {
                        while true
                            semaphore.synchronize do 
                                return if idx >= @image_urls.count
                                i = idx
                                idx += 1
                            end

                            filename = "%s/%03d-%s" % [dirname, i, @image_urls[i].split('/')[-1]]
                            open(@image_urls[i]) do |img|
                                File.open(filename, 'wb') do |stream|
                                    stream.write img.read
                                end
                            end
                        end
                    }.call
                end
            end

            threads.each {|t| t.join()}
        end
    end

    def self.get_chapter_list sample_chapter
        doc = Nokogiri::HTML open(sample_chapter, {ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE})
        doc_chap_list = doc.xpath '//select[@id="selectChapter"]/option/@value'
        return doc_chap_list.map &:content
    end

    def self.download_chapters chap_list, start_chap, end_chap, basedir, conc, speed, callback
        # Make the base dir
        FileUtils.mkdir_p basedir unless File.directory? basedir
        
        # Download
        idx = start_chap
        threads = []
        semaphore = Mutex.new
        conc = chap_list.count if conc > chap_list.count
        conc.times do
            threads << Thread.new do |th; i|
                lambda {
                    while true
                        semaphore.synchronize do
                            return if idx > end_chap
                            i = idx
                            idx += 1
                        end

                        start_ts = Time.now.to_f
                        chap = Chapter.new chap_list[i]
                        chap.download(basedir, speed, callback)
                        puts "Chapter #{chap.name} downloaded in %.3f seconds" % (Time.now.to_f - start_ts)
                    end
                }.call
            end
        end

        threads.each {|t| t.join()}
    end
end
