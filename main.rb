require 'sinatra'
require 'yaml'
require 'set'
require 'time'

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

  # replace with Date::DAYNAMES
  WEEK_DAYS = Set['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday']

  def initialize(timetable_hash = nil, scheduled_slots_hash = nil)
    @timetable = import_timetable(timetable_hash)
    @scheduled_slots = import_scheduled_slots(scheduled_slots_hash)
  end

  def import_timetable(timetable_hash)
    if timetable_valid?(timetable_hash)
      timetable_hash
    else
      {
        monday: Set[],
        tuesday: Set[],
        wednesday: Set[],
        thursday: Set[],
        friday: Set[],
        saturday: Set[],
        sunday: Set[]
      }
    end
  end

  def import_scheduled_slots(scheduled_slots_hash)
    if scheduled_slots_valid?(scheduled_slots_hash)
      scheduled_slots_hash.map do |date, hours|
        parsed_date = Time.parse(date.to_s)
        date = "#{parsed_date.year}/#{parsed_date.month}/#{parsed_date.day}"
        [date.to_sym, hours.to_set]
      end.to_h
      scheduled_slots_hash
    else
      Hash.new(Set[])
    end
  end

  def modify_hours(modified_hours_hash)
    if modified_hours_hash.instance_of?(Hash) && timetable_valid?(@timetable.merge(modified_hours_hash))
      @timetable.update(modified_hours_hash)
    end
    self
  end

  def future_meetings(start_date)
    today = start_date - 1
    @scheduled_slots.each_with_object(Hash.new(Set[])) do |(date, hours), hash|
      if Time.parse(date.to_s) > today
        hash.update({ date => hours })
      end
    end
  end

  def one_week_of_future_meetings(start_date)
    future_meetings(start_date).each_with_object(Hash.new(Set[])) do |(date, hours), hash|
      parsed_date = Date.parse(date.to_s)
      hash.update({ date.to_sym => hours }) if parsed_date >= start_date && parsed_date < start_date + 7
    end
  end

  def week_agenda_dates(start_date = Time.now.to_date.next_day)
    (0..6).each_with_object(Hash.new(Set[])) do |i, week_agenda|
      date = (Date.parse(start_date.to_s) + i)

      week_agenda.update(
        { 
          "#{date.year}/#{date.month}/#{date.day}".to_sym => week_agenda_wdays(start_date)[Date::DAYNAMES[date.wday].downcase.to_sym]
        })
    end
  end

  def week_agenda_wdays(start_date = Time.now.to_date.next_day)
    # excludes next day by default
    one_week_of_future_meetings(start_date).each_with_object(@timetable) do |(m_date, m_hours), timetable_hash|
      week_day = Date::DAYNAMES[Date.parse(m_date.to_s).wday].to_sym
      timetable_hash[week_day] = (timetable_hash[week_day].to_a - m_hours.to_a).to_set
    end
  end

  def schedule_meeting(day_or_date, hour)
    return unless proposed_meeting_valid?(day_or_date, hour)

    date = week_day_to_closest_date(day_or_date) if WEEK_DAYS.include?(day_or_date.to_s)

    return if meeting_already_exist?(date, hour)

    @scheduled_slots[date.to_sym] << hour
    @scheduled_slots[date.to_sym].sort
  end

  def cancel_meeting(day_or_date, hour)
    return unless proposed_meeting_valid?(day_or_date, hour)

    date = week_day_to_closest_date(day_or_date) if WEEK_DAYS.include?(day_or_date.to_s)

    return unless meeting_already_exist?(day, hour)

    @scheduled_slots[date.to_sym].delete(hour)
    @scheduled_slots[date.to_sym].sort
  end

  private

  def timetable_valid?(timetable_hash)
    return false unless timetable_hash.instance_of?(Hash)

    allowed_days = [].to_set + WEEK_DAYS
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

  def date_valid?(date)
    date_valid = true

    begin
      Time.parse(date.to_s)
    rescue ArgumentError, TypeError
      date_valid = false
    end

    date_valid
  end

  def scheduled_slots_valid?(scheduled_slots_hash)
    return false unless scheduled_slots_hash.instance_of?(Hash)

    invalid_not_found = true

    scheduled_slots_hash.each_pair do |date, hours|
      unless date_valid?(date) && hours_valid?(hours)
        invalid_not_found = false
        break
      end
    end

    invalid_not_found
  end

  def proposed_meeting_valid?(day_or_date, hour)
    hours_valid?([hour].to_set) &&
    (date_valid?(day_or_date.to_s) || WEEK_DAYS.include?(day_or_date.to_s))
  end

  def meeting_already_exist?(date, hour)
    @scheduled_slots[date].any?(hour)
  end

  def week_day_to_closest_date(week_day)
    # excluding today
    tomorrow = Time.now.to_date + 1

    # Sunday is 0 according to wday
    sorted_days = [] + WEEK_DAYS.to_a
    sorted_days = sorted_days.to_a.unshift(week_days.to_a.pop).to_set
    week_day = sorted_days.index(week_day.to_s)

    if week_day == tomorrow.wday
      tomorrow
    elsif week_day < tomorrow
      tomorrow + 7 - (tomorrow.wday - week_day)
    elsif week_day > tomorrow
      tomorrow + (week_day - tomorrow.wday)
    end
  end
end