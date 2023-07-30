require './main.rb'

describe Calendar do
  subject { Calendar.new(good_timetable) }

  let(:good_timetable) do
    {
      monday: Set[9, 10, 11],
      tuesday: Set[14, 15, 16],
      wednesday: Set[17, 18, 19],
      thursday: Set[],
      friday: Set[15],
      saturday: Set[20, 21],
      sunday: Set[13, 14, 15, 16, 17, 18]
    }
  end

  let(:empty_timetable) do
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

  let(:good_week_agenda) do
    {
      :'2023/7/29' => good_timetable[:saturday],
      :'2023/7/30' => good_timetable[:sunday],
      :'2023/7/31' => good_timetable[:monday],
      :'2023/8/1' => good_timetable[:tuesday],
      :'2023/8/2' => good_timetable[:wednesday],
      :'2023/8/3' => good_timetable[:thursday],
      :'2023/8/4' => good_timetable[:friday]
    }
  end

  let(:meetings_hash) do {
    :'2023/7/29' => Set[20, 21]
  }
  end
  
  context 'when setting timetable' do
    it 'returns the incoming hash if the incoming hash timetable is valid' do
      expect(subject.timetable).to eql(good_timetable)
    end

    it 'returns empty timetable if the incoming table does not use sets' do
      good_timetable[:monday] = [9, 10, 11]
      expect(subject.timetable).to eql(empty_timetable)
    end

    it 'returns empty timetable if the incoming table hours are not 0-24' do
      good_timetable[:monday] = Set[20, 21, 25]
      expect(subject.timetable).to eql(empty_timetable)
    end

    it 'returns empty timetable if the incoming table lacks day' do
      good_timetable[:monday] = nil
      expect(subject.timetable).to eql(empty_timetable)
    end

    it 'returns empty timetable if the incoming table has too many days' do
      good_timetable[:bruhday] = Set[10, 11, 12]
      expect(subject.timetable).to eql(empty_timetable)
    end

    it 'modifies the timetable if valid changes are made' do
      expected_timetable = good_timetable
      expected_timetable[:monday] = Set[12, 13, 14]
      expected_timetable[:friday] = Set[10, 11] 

      expect(subject.modify_hours({ monday: Set[12, 13, 14], friday: Set[10, 11] }).timetable).to eql(expected_timetable)
    end

    it 'does not modify the timetable if invalid changes are made' do
      expect(subject.modify_hours({ monday: Set[12, 13, 14, 25], friday: Set[10, 11] }).timetable).to eql(good_timetable)
    end
  end

  context 'when planning week agenda' do
    let!(:fake_today) { Time.parse("2023/7/28") } 
    # fake_today is friday

    before(:each) { allow(Time).to receive(:now) { fake_today } }

    it 'returns a hash with possible meeting dates starting tomorrow until one week ahead' do
      expect(subject.week_agenda_dates).to eql(good_week_agenda)
    end

    it 'returns a hash with possible meeting days starting tomorrow until one week ahead' do
      good_week_agenda = good_timetable

      expect(subject.week_agenda_wdays).to eql(good_week_agenda)
    end

    # xit 'returns a hash with possible meeting days starting today until one week ahead if configured' do
    #   allow(subject).to receive(:schedule_for_today?) { true }

    #   good_week_agenda[:'2023/7/28'] = good_timetable[:saturday]
    #   good_week_agenda[:'2023/8/4'] = nil

    #   expect(subject.week_agenda).to eql(good_week_agenda)
    # end

    it 'privately displays future meetings when scheduled slots are imported' do
      subject.import_scheduled_slots({:'2020/8/4' => Set[10], :'2023/8/4' =>  Set[20] })
      
      expect(subject.future_meetings).to eql({ :'2023/8/4' => Set[20] })
    end

    it 'privately converts week days to closest dates (excluding today)' do
      expect(subject.send(:week_day_to_closest_date, :friday)).to eql('2023/8/4')
    end

    it 'schedules meetings by dates' do
      # next friday
      subject.schedule_meeting(:'2023/8/4', 20)

      expect(subject.future_meetings).to eql({ :'2023/8/4' => Set[20] })
    end

    it 'schedules meetings by week days' do
      subject.schedule_meeting(:friday, 20)

      expect(subject.future_meetings).to eql({ :'2023/8/4' => Set[20]})
    end

    it 'cancels scheduled meetings by dates' do
      subject.schedule_meeting(:'2023/8/4', 20)
      subject.cancel_meeting(:'2023/8/4', 20)

      expect(subject.future_meetings).to eql({})
    end
    
    it 'cancels scheduled meetings by week days' do
      subject.schedule_meeting(:friday, 20)
      subject.cancel_meeting(:friday, 20)

      expect(subject.future_meetings).to eql({})
    end

    it 'cancels scheduled meetings and does not delete entire days if there are other meetings' do
      subject.schedule_meeting(:'2023/8/4', 20)
      subject.schedule_meeting(:'2023/8/4', 21)
      subject.cancel_meeting(:friday, 20) # it's still 2023/8/4

      expect(subject.future_meetings).to eql({ :'2023/8/4' => Set[21] })
    end

    it 'returns a hash with open slots for week days' do
      allow(subject).to receive(:future_meetings) { meetings_hash }
      good_week_agenda = good_timetable
      good_week_agenda[:saturday] = Set[]

      expect(subject.week_agenda_wdays).to eql(good_week_agenda)
    end

    it 'returns a hash with open slots for dates' do
      allow(subject).to receive(:future_meetings) { meetings_hash }
      good_week_agenda[:'2023/7/29'] = Set[]

      expect(subject.week_agenda_dates).to eql(good_week_agenda)
    end

    xit 'changes week agenda when a meeting is scheduled' do
      good_week_agenda[:'2023/7/29'] = Set[21]
      subject.schedule_meeting(:saturday, 20)

      expect(subject.week_agenda).to eql(good_week_agenda)
    end

    xit 'changes week agenda when a meeting is cancelled' do
      allow(subject).to receive(:future_meetings) { meetings_hash }
      subject.cancel_meeting(:saturday, 20)

      good_week_agenda[:'2023/7/29'] = Set[21]

      expect(subject.week_agenda).to eql(good_week_agenda)
    end

    xit 'outputs scheduled meetings' do
      subject.schedule_meeting(:saturday, 20)
      subject.schedule_meeting(:saturday, 21)

      expect(subject.future_meetings).to eql(meetings_hash)
    end
  end
end