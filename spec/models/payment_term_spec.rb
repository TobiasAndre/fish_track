require "rails_helper"

RSpec.describe PaymentTerm, type: :model do
  it_behaves_like "a loggable model" do
    let(:loggable_record) { build(:payment_term) }
  end

  it "is valid with a name" do
    expect(build(:payment_term)).to be_valid
  end

  it "is invalid without a name" do
    payment_term = build(:payment_term, name: nil)

    expect(payment_term).not_to be_valid
    expect(payment_term.errors[:name]).to be_present
  end

  it "is invalid with a duplicate name" do
    create(:payment_term, name: "30 dias")
    payment_term = build(:payment_term, name: "30 dias")

    expect(payment_term).not_to be_valid
    expect(payment_term.errors[:name]).to be_present
  end

  it "is invalid with a nil active flag" do
    payment_term = build(:payment_term, active: nil)

    expect(payment_term).not_to be_valid
    expect(payment_term.errors[:active]).to be_present
  end

  it "accepts a blank number of days (à vista)" do
    expect(build(:payment_term, days: nil)).to be_valid
  end

  it "accepts a non-negative integer number of days" do
    expect(build(:payment_term, days: 30)).to be_valid
  end

  it "is invalid with a negative number of days" do
    payment_term = build(:payment_term, days: -1)

    expect(payment_term).not_to be_valid
    expect(payment_term.errors[:days]).to be_present
  end

  describe "installments" do
    it "is invalid with less than one installment" do
      expect(build(:payment_term, installments_count: 0)).not_to be_valid
    end

    it "is invalid with a negative interval" do
      expect(build(:payment_term, interval_days: -1)).not_to be_valid
    end

    it "normalizes blank installment fields back to the defaults" do
      term = build(:payment_term, installments_count: "", interval_days: "")

      expect(term).to be_valid
      expect(term.installments_count).to eq(1)
      expect(term.interval_days).to eq(0)
    end

    it "parses day_offsets from a comma/space separated list" do
      term = build(:payment_term)
      term.day_offsets_list = "0, 30 ,  60"

      expect(term.day_offsets).to eq([0, 30, 60])
    end

    it "rejects negative custom offsets" do
      term = build(:payment_term)
      term.day_offsets_list = "0, -5, 30"

      expect(term).not_to be_valid
      expect(term.errors[:day_offsets]).to be_present
    end
  end

  describe "#installment_schedule" do
    it "returns a single installment on the given offset by default" do
      term = build(:payment_term, days: 30, installments_count: 1)

      schedule = term.installment_schedule(Date.new(2026, 1, 1), 30_000)

      expect(schedule.size).to eq(1)
      expect(schedule.first[:due_on]).to eq(Date.new(2026, 1, 31))
      expect(schedule.first[:amount_cents]).to eq(30_000)
    end

    it "splits evenly by count and interval, last installment absorbs the remainder" do
      term = build(:payment_term, days: 30, installments_count: 3, interval_days: 30)

      schedule = term.installment_schedule(Date.new(2026, 1, 1), 10_000)

      expect(schedule.map { |i| i[:amount_cents] }).to eq([3333, 3333, 3334])
      expect(schedule.map { |i| i[:due_on] }).to eq(
        [Date.new(2026, 1, 1) + 30, Date.new(2026, 1, 1) + 60, Date.new(2026, 1, 1) + 90]
      )
      expect(schedule.map { |i| i[:number] }).to eq([1, 2, 3])
      expect(schedule.map { |i| i[:of] }).to all(eq(3))
    end

    it "uses custom day_offsets when present, ignoring count and interval" do
      term = build(:payment_term, days: 999, installments_count: 1, interval_days: 999)
      term.day_offsets_list = "0, 15, 45"

      schedule = term.installment_schedule(Date.new(2026, 1, 1), 9_000)

      expect(schedule.map { |i| i[:due_on] }).to eq(
        [Date.new(2026, 1, 1), Date.new(2026, 1, 16), Date.new(2026, 2, 15)]
      )
      expect(schedule.map { |i| i[:amount_cents] }).to eq([3000, 3000, 3000])
    end
  end

  describe "#installments_summary" do
    it "reads 'À vista' for a single zero-day installment" do
      expect(build(:payment_term, days: 0, installments_count: 1).installments_summary).to eq("À vista")
    end

    it "describes an evenly spaced plan" do
      term = build(:payment_term, days: 30, installments_count: 3, interval_days: 30)

      expect(term.installments_summary).to eq("3× · 1º em 30d · a cada 30d")
    end

    it "describes a custom plan" do
      term = build(:payment_term)
      term.day_offsets_list = "0, 30, 60"

      expect(term.installments_summary).to eq("3× · 0/30/60d")
    end
  end
end
