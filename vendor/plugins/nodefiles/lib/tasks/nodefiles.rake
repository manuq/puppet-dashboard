require 'fileutils'
require "#{RAILS_ROOT}/lib/progress_bar"

namespace :nodefiles do
  desc "Import stored node files from $NODEFILES_DIR"
  task :import => :environment do
    nodefiles_dir = ENV['NODEFILES_DIR']

    plural = lambda{|str, count| str + (count != 1 ? 's' : '')}
    raise "Nodefiles dir does not exist: #{nodefiles_dir}" unless File.exists?(nodefiles_dir)
    raise "Nodefiles dir is not a directory: #{nodefiles_dir}" unless File.directory?(nodefiles_dir)
    raise "Nodefiles dir is not readable: #{nodefiles_dir}" unless File.readable?(nodefiles_dir)
    nodefiles = FileList[File.join(nodefiles_dir, '*', '*')]

    puts "Importing #{nodefiles.size} #{plural['nodefile', nodefiles.size]} from #{nodefiles_dir} in the background"

    skipped = 0
    pbar = ProgressBar.new("Importing:", nodefiles.size, STDOUT)
    nodefiles.each do |nodefile|
      success = begin
        #Report.delay.create_from_yaml_file(report)

        filename = File.basename(nodefile)
        host = File.basename(File.dirname(nodefile))

        directory = File.join("public/nodefiles", host)
        unless File.directory?(directory)
          FileUtils.mkdir_p(directory)
        end

        path = File.join(directory, filename)
        File.open(path, "wb") do |f|
          f.write(File.open(nodefile).read)
        end

        f = NodeFile.create(:filename => filename, :host => host)
        f.save()

      rescue => e
        puts e
        false
      end
      skipped += 1 unless success
      pbar.inc
    end
    pbar.finish

    successes = nodefiles.size - skipped

    puts "#{successes} of #{nodefiles.size} #{plural['nodefile', successes]} queued"
    puts "#{skipped} #{plural['nodefile', skipped]} skipped" if skipped > 0
  end

end
