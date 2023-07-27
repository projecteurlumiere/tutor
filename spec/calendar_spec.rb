require './main.rb'

describe Calendar do
  let(:good_timetable) do {
      monday: Set[9, 10, 11],
      tuesday: Set[14, 15, 16],
      wednesday: Set[17, 18, 19],
      thursday: Set[],
      friday: Set[],
      saturday: Set[20, 21],
      sunday: Set[13, 14, 15, 16, 17, 18]
    }
  end
  
  it "returns the incoming hash if the incoming hash timetable is valid" do
    expect(Calendar.new(good_timetable).timetable).to eql(good_timetable)
  end

  it "returns nil if the incoming table does not use sets" do
    good_timetable[:monday] = [9, 10, 11]
    expect(Calendar.new(good_timetable).timetable).to eql(nil)
  end

  it "returns nil if the incoming table hours are not 0-24" do
    good_timetable[:monday] = Set[20, 21, 25]
    expect(Calendar.new(good_timetable).timetable).to eql(nil)
  end

  it "returns nil if the incoming table lacks day" do
    good_timetable[:monday] = nil
    expect(Calendar.new(good_timetable).timetable).to eql(nil)
  end

  it "returns nil if the incoming table has too many days" do
    good_timetable[:bruhday] = Set[10, 11, 12]
    expect(Calendar.new(good_timetable).timetable).to eql(nil)
  end

  it "modifies the timetable if valid changes are made" do
    expected_timetable = good_timetable
    expected_timetable[:monday] = Set[12, 13, 14]
    expected_timetable[:friday] = Set[10, 11] 

    expect(Calendar.new(good_timetable).modify_hours({ monday: Set[12, 13, 14], friday: Set[10, 11] }).timetable).to eql(expected_timetable)
  end

  it "does not modify the timetable if invalid changes are made" do 
    expect(Calendar.new(good_timetable).modify_hours({ monday: Set[12, 13, 14, 25], friday: Set[10, 11] }).timetable).to eql(good_timetable)
  end
end