# Folha de um funcionário numa competência: salário base, bônus, adiantamentos,
# descontos, pagamento e saldo. É a mesma conta do cartão da página Folha e do
# demonstrativo em PDF enviado ao funcionário, para os dois nunca divergirem.
#
# Salário base + bônus - adiantamentos - descontos = líquido. O adiantamento de
# 13º é informativo: não sai do salário do mês. No mês do desligamento o salário
# base fica zerado (o acerto rescisório tem relatório próprio).
class PayrollStatement
  attr_reader :employee, :year, :month, :competence_date, :items

  def initialize(employee, year:, month:, items: nil)
    @employee = employee
    @year = year.to_i
    @month = month.to_i
    @competence_date = Date.new(@year, @month, 1)
    @items = (items || employee.payroll_items.where(year: @year, month: @month).order(created_at: :asc)).to_a
  end

  def advances = of_type("advance")
  def thirteenth_advances = of_type("thirteenth_advance")
  def bonuses = of_type("bonus")
  def discounts = of_type("discount")

  def salary_payment
    items.find { |item| item.item_type == "salary_payment" }
  end

  def total_advance_cents = advances.sum(&:amount_cents)
  def total_thirteenth_advance_cents = thirteenth_advances.sum(&:amount_cents)
  def total_bonus_cents = bonuses.sum(&:amount_cents)
  def total_discount_cents = discounts.sum(&:amount_cents)

  def terminated_this_month?
    employee.terminated? && employee.terminated_on.present? &&
      employee.terminated_on.year == year && employee.terminated_on.month == month
  end

  def salary_cents
    terminated_this_month? ? 0 : employee.salary_on(competence_date).to_i
  end

  # Proventos (salário + bônus) e deduções (adiantamentos + descontos) do mês.
  def earnings_cents = salary_cents + total_bonus_cents
  def deductions_cents = total_advance_cents + total_discount_cents

  # Líquido do mês (nunca negativo).
  def remaining_cents
    [earnings_cents - deductions_cents, 0].max
  end

  def paid_cents
    salary_payment&.amount_cents.to_i
  end

  def outstanding_cents
    [remaining_cents - paid_cents, 0].max
  end

  # "09/2026"
  def competence_label
    format("%02d/%d", month, year)
  end

  private

  def of_type(type)
    items.select { |item| item.item_type == type }
  end
end
