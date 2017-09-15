# This file should contain all the record creation needed to seed the database with its default values, or update those values when necessary.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
require 'yaml'

def bulleit?
  return true if Socket.gethostname == 'bulleit-1.umdl.umich.edu'
  false
end

def update_create(entry)
  Press.where(subdomain: entry["subdomain"]).first_or_initialize.tap do |press|
    press.name = entry["name"]
    press.description = entry["description"]
    press.subdomain = entry["subdomain"]
    press.press_url = entry["press_url"]
    press.google_analytics = entry["google_analytics"] if bulleit?
    press.typekit = entry["typekit"]
    press.footer_block_a = entry["footer_block_a"]
    press.footer_block_c = entry["footer_block_c"]
    if press.save
      puts "updated/created #{entry["subdomain"]}"
    else
      puts "#{entry["subdomain"]} update/create FAILED #{press.errors.messages.inspect}"
    end
  end
end

unless Rails.env.test?
  publishers = begin
    YAML.load(File.open("db/publishers.yml"))
  rescue ArgumentError => e
    puts "Could not parse YAML: #{e.message}"
  end
  publishers.each_entry do |entry|
    if bulleit?
      update_create(entry) if entry["production"]
    else
      update_create(entry)
    end
  end
end
