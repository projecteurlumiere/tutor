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

# all dates to strings and parse.date.to_s should be key
# all symbols = to array
#

class Calendar
  attr_reader :timetable

  WEEK_DAYS = Date::DAYNAMES.map(&:downcase)

  def initialize(timetable_hash = nil, scheduled_slots_hash = nil)
    @timetable = import_timetable(timetable_hash)
    import_scheduled_slots(scheduled_slots_hash)
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
    @scheduled_slots = if scheduled_slots_valid?(scheduled_slots_hash)
      scheduled_slots_hash.map do |date, hours|
        [Date.parse(date).to_s, hours.to_set]
      end.to_h
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

  def future_meetings(start_date = Time.now.to_date + 1)
    @scheduled_slots.each_with_object(Hash.new(Set[])) do |(date, hours), hash|
      hash.update({ date => hours }) if Date.parse(date) >= start_date
    end
  end

  def one_week_of_future_meetings(start_date)
    future_meetings(start_date).each_with_object(Hash.new(Set[])) do |(date, hours), hash|
      parsed_date = Date.parse(date.to_s)
      hash.update({ date => hours }) if parsed_date >= start_date && parsed_date < start_date + 7
    end
  end

  def week_agenda_dates(start_date = Time.now.to_date.next_day)
    one_week_of_future_meetings(start_date).each_with_object(timetable_with_date_keys(start_date)) do |(key, value), t_hash|
      t_hash[key] = (t_hash[key].to_a - value.to_a).to_set
    end
  end

  def week_agenda_wdays(start_date = Time.now.to_date.next_day)
    # excludes next day by default
    one_week_of_future_meetings(start_date).each_with_object(@timetable) do |(m_date, m_hours), t_hash|
      week_day = Date::DAYNAMES[Date.parse(m_date).wday]
      t_hash[week_day] = (t_hash[week_day].to_a - m_hours.to_a).to_set
    end
  end

  def schedule_meeting(day_or_date, hour)
    return unless proposed_meeting_valid?(day_or_date, hour)

    if WEEK_DAYS.include?(day_or_date.to_s)
      date = week_day_to_closest_date(day_or_date)
    else 
      date = day_or_date
    end

    unless meeting_already_exist?(date, hour)
      @scheduled_slots[date] = @scheduled_slots[date] << hour
      @scheduled_slots[date].sort
    end
  end

  def cancel_meeting(day_or_date, hour)
    return unless proposed_meeting_valid?(day_or_date, hour)

    if WEEK_DAYS.include?(day_or_date.to_s)
      date = week_day_to_closest_date(day_or_date)
    else 
      date = day_or_date
    end

    if meeting_already_exist?(date, hour)
      @scheduled_slots[date].delete(hour)
      if @scheduled_slots[date].empty?
        @scheduled_slots.delete(date)
      else
        @scheduled_slots[date].sort
      end
    end
  end

  private

  def timetable_valid?(timetable_hash)
    return false unless timetable_hash.instance_of?(Hash)

    allowed_days = WEEK_DAYS.to_set
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
      Date.parse(date)
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
    (WEEK_DAYS.include?(day_or_date.to_s) || date_valid?(day_or_date))
  end

  def meeting_already_exist?(date, hour)
    @scheduled_slots[date].any?(hour)
  end

  def week_day_to_closest_date(week_day, start_day = Time.now.to_date.next_day)
    # start day is tomorrow by default

    # Sunday is 0 according to wday
    week_day = Date::DAYNAMES.index(week_day.to_s.capitalize)

    if week_day == start_day.wday
      start_day
    elsif week_day < start_day.wday
      start_day + 7 - (start_day.wday - week_day)
    elsif week_day > start_day
      start_day + (week_day - start_day.wday)
    end.to_s
  end

  def timetable_with_date_keys(start_date)
    new_timetable = Hash.new(Set[])
    (0..6).each do |day|
      new_timetable[(start_date + day).to_s] = nil
    end

    new_timetable.each_with_object(timetable_daynames_to_numbers) do |(date, hours), timetable_hash|
      new_timetable[date] = timetable_hash[Date.parse(date).wday]
    end

    new_timetable
  end

  def timetable_daynames_to_numbers
    @timetable.each_with_object(Hash.new(Set[])) do |(wday, hours), new_hash|
      new_hash[WEEK_DAYS.index(wday.to_s.downcase)] = hours
    end
  end
end