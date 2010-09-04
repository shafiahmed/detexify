require 'restclient'
require 'json'
require 'base64'
require 'puddle'
require 'armchair'
require 'classinatra/client'

class PopulateTask < Rake::TaskLib
  
  def initialize name = :populate
    @name = name
    define
  end
  
  def define
    desc "Populate a CLASSIFIER with existing data from TRAINCOUCH."
    task @name do
      unless ENV['CLASSIFIER'] && ENV['TRAINCOUCH']
        abort "You must set CLASSIFIER and TRAINCOUCH environment variables!"
      end
      
      classifier = Classinatra::Client.at(ENV['CLASSIFIER'])
      couch = Armchair.new(ENV['TRAINCOUCH'])
      couch.create!
      
      count = couch.size.to_f
      progress = 0.0
      percent = 0.0

      start = Time.now.to_i
      pool = Puddle.new
      couch.each do |doc|
        pool.process do
          next unless doc['data'] && doc['id']
          data = JSON(doc['data'])
          id = doc['id']
          tries = 0
          begin
            tries += 1
            classifier.train id, data
          rescue RestClient::Exception => e
            puts "Error: {e.message}"
            if tries < 4
              puts "retrying in #{tries**2} seconds"
              sleep tries**2
              retry
            end
          end
          progress += 1
          puts "#{percent = (progress*100.0/count).floor}% geladen" if (progress*100.0/count).floor > percent
        end
      end # count.each
      puts "done. #{(Time.now.to_i-start)} secs."
      pool.drain
    end
  end

end