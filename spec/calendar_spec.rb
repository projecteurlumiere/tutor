require_relative 'main'

describe Calendar do
  subject { Calendar.new(good_timetable) }

  let(:fake_today) { fake_today = Time.parse("2023-07-28") } 
  # fake_today is friday

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

  let(:good_week_agenda) do
    {
      :'2023_07_29' => good_timetable[:saturday],
      :'2023_07_30' => good_timetable[:sunday],
      :'2023_07_31' => good_timetable[:monday],
      :'2023_08_01' => good_timetable[:tuesday],
      :'2023_08_02' => good_timetable[:wednesday],
      :'2023_08_03' => good_timetable[:thursday],
      :'2023_08_04' => good_timetable[:friday]
    }
  end

  let(:occupied_slots_hash) do {
    :'2023_07_29' => Set[20, 21]
  }
  end
  
  context 'when setting timetable' do
    it 'returns the incoming hash if the incoming hash timetable is valid' do
      expect(subject.timetable).to eql(good_timetable)
    end

    it 'returns nil if the incoming table does not use sets' do
      good_timetable[:monday] = [9, 10, 11]
      expect(subject.timetable).to eql(nil)
    end

    it 'returns nil if the incoming table hours are not 0-24' do
      good_timetable[:monday] = Set[20, 21, 25]
      expect(subject.timetable).to eql(nil)
    end

    it 'returns nil if the incoming table lacks day' do
      good_timetable[:monday] = nil
      expect(subject.timetable).to eql(nil)
    end

    it 'returns nil if the incoming table has too many days' do
      good_timetable[:bruhday] = Set[10, 11, 12]
      expect(subject.timetable).to eql(nil)
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
    before(:all) { allow(Time).to receive(:now) { fake_today } }

    it 'returns a hash with possible meeting days starting tomorrow until one week ahead' do
      expect(subject.week_agenda).to eql(good_week_agenda)
    end

    it 'returns a hash with possible meeting days starting today until one week ahead if configured' do
      allow(subject).to receive(:schedule_for_today?) { true }

      good_week_agenda[:'2023_07_28'] = good_timetable[:saturday]
      good_week_agenda[:'2023_08_04'] = nil

      expect(subject.week_agenda).to eql(good_week_agenda)
    end

    it 'returns a hash with possible meeting days taking into account meetings that are already scheduled' do
      allow(subject).to receive(:future_scheduled_slots) { occupied_slots_hash }
      good_week_agenda[:'2023_07_29'] = Set[]

      expect(subject.week_agenda).to eql(good_week_agenda)
    end

    it 'changes week agenda when a meeting is scheduled' do
      good_week_agenda[:'2023_07_29'] = Set[21]
      subject.schedule_meeting(:saturday, 20)

      expect(subject.week_agenda).to eql(good_week_agenda)
    end

    it 'changes week agenda when a meeting is cancelled' do
      allow(subject).to receive(:future_scheduled_slots) { occupied_slots_hash }
      subject.cancel_meeting(:saturday, 20)

      good_week_agenda[:'2023_07_29'] = Set[21]

      expect(subject.week_agenda).to eql(good_week_agenda)
    end

    it 'outputs scheduled meetings' do
      subject.schedule_meeting(:saturday, 20)
      subject.schedule_meeting(:saturday, 21)

      expect(subject.future_scheduled_slots).to eql(occupied_slots_hash)
    end

    xit 'schedules meetings by dates' do
      # next friday
      subject.schedule_meeting(:'2023_08_04', 20)

      expect(subject.future_scheduled_slots).to eql({ :'2023_08_04' => 20 })
    end
  end
end