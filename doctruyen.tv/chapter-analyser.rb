require 'openssl'
require 'open-uri'
require 'nokogiri'
require 'selenium-webdriver'


module DocTruyen
    S_OPTIONS = Selenium::WebDriver::Chrome::Options.new(args: ['headless'])

    class Chapter
        def initialize url
            # Get chapter name from url
            @url = url
            @name = url.split('/')[-1].split('-')[0..-2].join('-')
            @scraper_driver = Selenium::WebDriver.for(:chrome, options: S_OPTIONS)
        end

        def download base_dir, callback
            puts "Start downloading #{@name}..."

            @scraper_driver.get @url
            div_reader = @scraper_driver.find_element(:id, 'reader')
            reader_xml = div_reader.execute_script('return arguments[0].innerHTML', div_reader)
            doc = Nokogiri::XML reader_xml
            images_urls = doc.xpath('//img/@src').map(&:content)
        end
    end

    def self.get_chapter_list sample_chapter
        doc = Nokogiri::HTML open(sample_chapter, {ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE})
        doc_chap_list = doc.xpath '//select[@id="selectChapter"]/option/@value'
        return doc_chap_list
    end

    def self.download_chapters chap_list, basedir, callback
        
    end
end
