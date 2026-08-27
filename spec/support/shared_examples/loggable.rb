RSpec.shared_examples "a loggable model" do
  it "logs creation as an ActivityLog entry" do
    Current.user = create(:user)

    loggable_record.save!

    log = ActivityLog.find_by(resource_type: loggable_record.class.name, resource_id: loggable_record.id, action: "create")

    expect(log).to be_present
    expect(log.user).to eq(Current.user)
    expect(log.description).to be_present
  end

  it "logs destruction as an ActivityLog entry" do
    Current.user = create(:user)
    loggable_record.save!
    id = loggable_record.id

    loggable_record.destroy!

    log = ActivityLog.where(resource_type: loggable_record.class.name, resource_id: id, action: "destroy")
                      .order(:created_at).last

    expect(log).to be_present
  end

  it "does not log when there is no current user" do
    Current.user = nil

    loggable_record.save!

    logs = ActivityLog.where(resource_type: loggable_record.class.name, resource_id: loggable_record.id)
    expect(logs).to be_empty
  end
end
