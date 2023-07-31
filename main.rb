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

  WEEK_DAYS = Date::DAYNAMES.map(&:downcase)

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
        parsed_date = Time.parse(date.to_s).to_date
        date = format_date_from_string_or_object(parsed_date)
        [date.to_sym, hours.to_set]
      end.to_h
      @scheduled_slots = scheduled_slots_hash
    else
      @scheduled_slots = Hash.new(Set[])
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
      if Time.parse(date.to_s).to_date >= start_date
        hash.update({ date => hours })
      end
    end
  end

  def one_week_of_future_meetings(start_date)
    future_meetings(start_date).each_with_object(Hash.new(Set[])) do |(date, hours), hash|
      parsed_date = Date.parse(date.to_s)
      hash.update({ date => hours }) if parsed_date >= start_date && parsed_date < start_date + 7
    end
  end

  def week_agenda_dates(start_date = Time.now.to_date.next_day)
    one_week_of_future_meetings(start_date).each_with_object(timetable_with_date_keys(start_date)) do |(key, value), timetable_hash|
      timetable_hash[key] = (timetable_hash[key].to_a - value.to_a).to_set
    end
    
    # one_week_of_future_meetings(start_date).each_with_object(@timetable) do |(m_date, m_hours), timetable_hash|
    #   week_day = Date::DAYNAMES[Date.parse(m_date.to_s).wday].to_sym
    #   puts "m_date is #{m_date}"
    #   timetable_hash[m_date] = (timetable_hash[week_day].to_a - m_hours.to_a).to_set
    # end
  end

  def week_agenda_wdays(start_date = Time.now.to_date.next_day)
    # excludes next day by default
    one_week_of_future_meetings(start_date).each_with_object(@timetable) do |(m_date, m_hours), timetable_hash|
      week_day = Date::DAYNAMES[Date.parse(m_date.to_s).wday].to_sym
      timetable_hash[week_day] = (timetable_hash[week_day].to_a - m_hours.to_a).to_set
    end
  end

  def schedule_meeting(day_or_date, hour)
    puts "day or date is #{day_or_date} and hour is #{hour}"
    
    return unless proposed_meeting_valid?(day_or_date, hour)

    puts "metting is valid"

    if WEEK_DAYS.include?(day_or_date.to_s)
      puts "converting days to date"
      date = week_day_to_closest_date(day_or_date)
      puts "converted to #{date}"
    else 
      puts "no need in conversion"
      date = day_or_date
      puts "date is #{date}"
    end

    return if meeting_already_exist?(date, hour)

    puts "meeting does not exist\nscheduled slots are #{@scheduled_slots}"

    @scheduled_slots[date.to_sym] = @scheduled_slots[date.to_sym] << hour

    puts "updated @scheduled_slots: #{@scheduled_slots}"
    @scheduled_slots[date.to_sym].sort
  end

  def cancel_meeting(day_or_date, hour)
    return unless proposed_meeting_valid?(day_or_date, hour)

    if WEEK_DAYS.include?(day_or_date.to_s)
      date = week_day_to_closest_date(day_or_date) 
    else 
      date = day_or_date
    end

    return unless meeting_already_exist?(date, hour)

    @scheduled_slots[date.to_sym].delete(hour)

    if @scheduled_slots[date.to_sym].empty?
      @scheduled_slots.delete(date.to_sym)
    else
      @scheduled_slots[date.to_sym].sort
    end
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
    week_day = Date::DAYNAMES.index(week_day.to_s.capitalize)

    format_date_from_string_or_object do
      if week_day == tomorrow.wday.to_i
        tomorrow
      elsif week_day < tomorrow.wday.to_i
        tomorrow + 7 - (tomorrow.wday.to_i - week_day)
      elsif week_day > tomorrow
        tomorrow + (week_day - tomorrow.wday.to_i)
      end
    end
  end

  def format_date_from_string_or_object(date_object = nil)
    if block_given?
      date = yield
    elsif 
      date = date_object
    end

    date = Date.parse(date) unless date.instance_of?(Date)

    "#{date.year}/#{date.month}/#{date.day}"
  end

  def timetable_with_date_keys(start_date)
    new_timetable = Hash.new(Set[])
    (0..6).each do |day|
      new_timetable[format_date_from_string_or_object(start_date + day)] = nil
    end

    new_timetable.each_with_object(timetable_daynames_to_numbers) do |(date, hours), timetable_hash|
      new_timetable[date] = timetable_hash[Date.parse(date).wday]
    end

    new_timetable.transform_keys(&:to_sym)
  end

  def timetable_daynames_to_numbers
    @timetable.each_with_object(Hash.new(Set[])) do |(wday, hours), new_hash|
      new_hash[WEEK_DAYS.index(wday.to_s.downcase)] = hours
    end
  end
end