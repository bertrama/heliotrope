# This file should contain all the record creation needed to seed the database with its default values, or update those values when necessary.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
def bulleit?
  return true if Socket.gethostname == 'bulleit-1.umdl.umich.edu'
  false
end

def heliotrope
  Press.where(name: 'Heliotrope Press').first_or_initialize.tap do |press|
    press.subdomain = 'heliotrope'
    press.description = 'Heliotrope Press'
    press.save
  end
  puts "updated/created heliotrope"
end

def michigan
  Press.where(name: 'University of Michigan Press').first_or_initialize.tap do |press|
    press.logo_path = 'michigan.png'
    press.description = 'University of Michigan Press is a leading publisher of books and digital projects in the humanities and social sciences that are aligned with the strengths of its parent institution. Areas of particular focus are performing arts, classical studies, political science, area studies, disability and class studies, English Language Teaching, and the social, cultural, and environmental history of the Great Lakes region of the US.<br/><br/>[michigan.fulcrum.org](https://michigan.fulcrum.org) is the home of supplemental content for select books and the location of enriched digital titles. You can find the full catalog of University of Michigan Press titles at [the publisher\'s website](http://www.press.umich.edu/).'
    press.subdomain = 'michigan'
    press.press_url = 'http://www.press.umich.edu'
    press.typekit = 'umv2ydc'
    press.google_analytics = 'UA-77847516-8' if bulleit?
    press.save
  end
  puts "updated/created michigan"
end

def pennstate
  Press.where(name: 'Penn State University Press').first_or_initialize.tap do |press|
    press.logo_path = 'pennstate.png'
    press.description = 'Penn State University Press publishes books and journals of the highest quality for a worldwide audience of scholars, students, and non-academic readers, with an emphasis on core fields of the humanities and social sciences. This page features supplemental content for select PSU Press titles. You can find the complete catalog of our publications and additional information about the Press on our [website](http://www.psupress.org/).'
    press.footer_block_a = '© Penn State University Press 2016'
    press.footer_block_c = 'http://www.psupress.org'
    press.subdomain = 'pennstate'
    press.press_url = 'http://www.psupress.org'
    press.typekit = 'cbh1mev'
    press.google_analytics = 'UA-77847516-7' if bulleit?
    press.save
  end
  puts "updated/created pennstate"
end

def indiana
  Press.where(name: 'Indiana University Press').first_or_initialize.tap do |press|
    press.logo_path = 'indiana.png'
    press.description = "Indiana University Press's mission is to inform and inspire scholars, students, and thoughtful general readers by disseminating ideas and knowledge of global significance, regional importance, and lasting value."
    press.subdomain = 'indiana'
    press.press_url = 'http://www.iupress.indiana.edu'
    press.google_analytics = 'UA-77847516-6' if bulleit?
    press.save
  end
  puts "updated/created indiana"
end

def northwestern
  Press.where(name: 'Northwestern University Press').first_or_initialize.tap do |press|
    press.logo_path = 'northwestern.png'
    press.description = "Northwestern University Press is dedicated to publishing works of enduring scholarly and cultural value, extending the University’s mission to a community of readers throughout the world.<br/><br/>[northwestern.fulcrum.org](http://northwestern.fulcrum.org) is the home of supplemental content for select books. You can find the full catalog of Northwestern University Press titles at the [publisher's website](http://www.nupress.northwestern.edu/)."
    press.subdomain = 'northwestern'
    press.press_url = 'http://nupress.northwestern.edu/'
    press.typekit = 'wyq1mfc'
    press.google_analytics = 'UA-77847516-3' if bulleit?
    press.save
  end
  puts "updated/created northwestern"
end

def minnesota
  Press.where(name: 'University of Minnesota Press').first_or_initialize.tap do |press|
    press.logo_path = 'minnesota.png'
    press.description = "Established in 1925, the University of Minnesota Press is recognized internationally for its innovative, boundary-breaking editorial program in the humanities and social sciences, and is committed to publishing books on the people, history, and natural environment of Minnesota and the Upper Midwest.<br/><br/>This page is the home of supplemental content for select University of Minnesota Press books. You can find the full catalog of Minnesota titles on the [publisher's website](https://www.upress.umn.edu/)."
    press.subdomain = 'minnesota'
    press.press_url = 'https://www.upress.umn.edu/'
    press.typekit = 'vqj2dgv'
    press.google_analytics = 'UA-77847516-5' if bulleit?
    press.save
  end
  puts "updated/created minnesota"
end

if Rails.env.eql?('production')
  # add presses as they become ready for production
  heliotrope unless bulleit?
  northwestern
  minnesota
  indiana
  pennstate unless bulleit?
else
  heliotrope
  northwestern
  pennstate
  indiana
  minnesota
  michigan
end
