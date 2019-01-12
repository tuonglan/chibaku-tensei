require 'optparse'
require_relative 'chapter-analyser'

if __FILE__ == $0
    # Argument parser
    options = {concurrency: 1,
               speed: 1, 
               title: "unknown",
               base_dir: '/tmp'}
    OptionParser.new do |opts|
        opts.banner = "Usage: ruby main.rb [options]"
        
        opts.on("-c", "--chapter_url CHAPTERURL", "Specify a sample chapter for analyzing") do |c|
                options[:chapter_url] = c
        end
        opts.on("-d", "--download_list R", "Specify list of chapter to download") {|d| options[:download_list] = d}
        opts.on('t', '--concurrency R', "Set number of threadsj") {|t| options[:concurrency] = t.to_i}
        opts.on('-b', '--base_dir R', "Set base dir for download") {|b| options[:base_dir] = b}
        opts.on('-n', '--title R', "Set comics name") {|n| options[:title] = n}
        opts.on('-s', '--speed R', "Set download speed") {|s| options[:speed] = s.to_i}
        
        opts.on('-h', '--help', 'Print this help') do puts opts; exit end
    end.parse!

    puts "Getting list of chapter"
    chap_list = DocTruyen.get_chapter_list(options[:chapter_url])
    
    # If not specify list to download, print and exitj
    if not options[:download_list]
        puts "There're #{chap_list.count} chapters to download, please set a range to download, ENTER to exit"
        puts "\tFormat \"start-end\""
        ls = gets.chomp
        exit if ls == ''
        options[:download_list] = ls
    end

    # Start downloading
    start_chap, end_chap = options[:download_list].split('-').map(&:to_i)
    puts "Start downloading from chapter #{start_chap} to chapter #{end_chap}..."
    DocTruyen.download_chapters(chap_list, start_chap-1, end_chap-1, "#{options[:base_dir]}/#{options[:title]}", 
                                options[:concurrency], options[:speed], nil)
end
