FactoryBot.define do
  factory :water_quality_reading do
    pond
    measured_at { Time.current.change(sec: 0) }
    ph { 7.4 }
  end
end
