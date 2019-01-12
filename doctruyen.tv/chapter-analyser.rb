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
        def initialize url, log_enabled=false
            # Get chapter name from url
            @url = url
            @name = url.split('/')[-1].split('-')[0..-2].join('-')
            @scraper_driver = Selenium::WebDriver.for(:chrome, options: S_OPTIONS)
            @log_enabled = log_enabled
            
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
            error_list = []
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

                            effort_count = 0
                            while true
                                effort_count += 1
                                begin
                                    filename = "%s/%03d-%s" % [dirname, i, @image_urls[i].split('/')[-1]]
                                    open(@image_urls[i]) do |img|
                                        File.open(filename, 'wb') do |stream|
                                            stream.write img.read
                                        end
                                    end
                                    break
                                rescue
                                    if effort_count > 3
                                        error_list << @image_urls[i]
                                        break
                                    end
                                    if @log_enabled
                                        puts "Error when trying to download #{@image_urls[i]}, try again #{effort_count}"
                                    end
                                end
                            end
                        end
                    }.call
                end
            end

            threads.each {|t| t.join()}
            if error_list.count > 0
                raise Exception("Error list #{error_list.join(',')}")
            end
        end

        def close
            @scraper_driver.close
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
        error_list = []
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
                        begin
                            chap = Chapter.new chap_list[i]
                            chap.download(basedir, speed, callback)
                            chap.close
                            puts "Chapter #{chap.name} downloaded in %.3f seconds" % (Time.now.to_f - start_ts)
                        rescue Exception => e
                            chap_name = chap_list[i].split('/')[-1].split('-')[0..-2].join('-')
                            txt = "Chapter #{chap_name}, index #{i+1}"
                            error_list << txt
                            puts "====> Error when downloading: #{txt}"
                        end
                    end
                }.call
            end
        end

        threads.each {|t| t.join()}
        puts "Downloaded #{end_chap - start_chap + 1 - error_list.count} chapters of total #{end_chap-start_chap+1}"
        puts "Chapters which has error when downloading"
        puts error_list
    end

    def self.download_chapter chap_url, basedir, speed, callback
        # Make the base dir
        FileUtils.mkdir_p basedir unless File.directory? basedir
        start_ts = Time.now.to_f
        chap = Chapter.new(chap_url, true)
        chap.download(basedir, speed, callback)
        puts "Chapter #{chap.name} downloaded in %.3f seconds" % (Time.now.to_f - start_ts)
    end
end
