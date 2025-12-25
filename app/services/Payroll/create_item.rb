class Payroll::CreateItem
  def self.call!(item)
    return if item.item_type == "discount"

    FinancialEntry.create!(
      company: item.company,
      entry_type: "expense",
      stage: "general",
      occurred_on: Date.new(item.year, item.month, 28),
      amount_cents: item.amount_cents,
      description: payroll_description(item)
    )
  end

  def self.payroll_description(item)
    case item.item_type
    when "advance"
      "Adiantamento salarial - #{item.employee.name}"
    when "salary"
      "Salário - #{item.employee.name}"
    when "bonus"
      "Bônus - #{item.employee.name}"
    end
  end
end
