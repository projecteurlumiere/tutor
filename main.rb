require 'sinatra'
require 'yaml'
require 'set'

# require 'i18n'

get '/' do
  erb :index
end

post 'set_rendez-vous/?' do
  params['email']
end

# get calendar:
# allowed days of weeks 
# hash: monday: 11,12,13,14
# then, checking what is the day today to form a hash of 
# weekdays on a week forward and hours 

# post meeting:
# email: abc@fdoiu.com
# date: 01-01-2022, 11:00

class Calendar
  attr_reader :timetable

  def initialize(timetable_hash)
    @timetable = nil
    @timetable = timetable_hash if timetable_hash.instance_of?(Hash) && timetable_valid?(timetable_hash)
  end

  def modify_hours(modified_hours_hash)
    if modified_hours_hash.instance_of?(Hash) && timetable_valid?(@timetable.merge(modified_hours_hash))
      @timetable.merge!(modified_hours_hash)
    end
    self
  end

  private

  def timetable_valid?(timetable_hash)
    allowed_days = Set['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday']
    invalid_not_found = true

    timetable_hash.each_pair do |day, hours|
      day = day.to_s
      if allowed_days.include?(day) && hours.instance_of?(Set) && hours_valid?(hours)
        allowed_days.delete(day)
      else
        invalid_not_found = false
        break
      end
    end

    invalid_not_found
  end

  def hours_valid?(hours_set)
    invalid_not_found = true

    hours_set.each_with_index do |hour, index|
      invalid_not_found = false unless index < 24 && hour.between?(0, 23)
    end

    invalid_not_found
  end
end