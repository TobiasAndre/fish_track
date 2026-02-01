class Employee < ApplicationRecord
  has_many :payroll_items, dependent: :destroy

  validates :name, presence: true
  validates :salary_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def payroll_balance(year:, month:)
    items = payroll_items.where(year: year, month: month)

    salary   = items.salary.sum(:amount_cents)
    advances = items.advance.sum(:amount_cents)
    bonuses  = items.bonus.sum(:amount_cents)
    discounts = items.discount.sum(:amount_cents)

    {
      salary_cents: salary,
      advances_cents: advances,
      bonuses_cents: bonuses,
      discounts_cents: discounts,
      net_to_pay_cents: salary + bonuses - advances - discounts
    }
  end
end
