desc 'get file_set urls and file_set labels for a monograph'
namespace :heliotrope do
  task :file_set_urls, [:monograph_id] => :environment do |t, args|

    # Usage: Needs a valid monograph id as a parameter
    # $ bundle exec rake "heliotrope:file_set_urls[q811kk573]" > ~/whatever.csv

    m = Monograph.find(args.monograph_id)

    m.ordered_members.to_a.each do |member|
      if member.file_set?
        # we're including the cover (and whatever other files attached to the monograph) here...
        puts "\"#{Rails.application.routes.url_helpers.curation_concerns_file_set_path(member.id)}\",\"#{member.label}\""
      else
        s = Section.find(member.id)
        s.ordered_members.to_a.each do |file_set|
          puts "\"#{Rails.application.routes.url_helpers.curation_concerns_file_set_path(file_set.id)}\",\"#{file_set.label}\""
        end
      end
    end
  end
end
