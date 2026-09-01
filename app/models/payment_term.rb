class PaymentTerm < ApplicationRecord
  include Loggable

  before_validation :normalize_installment_fields

  validates :name, presence: true, uniqueness: true
  validates :active, inclusion: { in: [true, false] }
  validates :days, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :installments_count, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  validates :interval_days, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :day_offsets_must_be_non_negative_integers

  # Lista de vencimentos (em dias a partir da data base). Quando `day_offsets`
  # está preenchido, ele manda -- serve para prazos irregulares (ex.: 0/30/60).
  # Caso contrário, deriva de installments_count + interval_days, com a 1ª
  # parcela em `days`.
  def installment_offsets
    return day_offsets.map(&:to_i) if day_offsets.present?

    count = [installments_count.to_i, 1].max
    first = days.to_i
    step = interval_days.to_i

    Array.new(count) { |i| first + i * step }
  end

  def installments?
    installment_offsets.size > 1
  end

  # Gera a agenda de parcelas para um valor total, dividindo em partes iguais e
  # jogando o arredondamento na última parcela.
  #
  #   term.installment_schedule(Date.new(2026, 1, 1), 100_00)
  #   => [{ number: 1, of: 3, due_on: ..., amount_cents: 3333 }, ...]
  def installment_schedule(base_date, total_cents)
    return [] if base_date.blank?

    offsets = installment_offsets
    count = offsets.size
    per = total_cents.to_i / count
    remainder = total_cents.to_i - (per * count)

    offsets.each_with_index.map do |offset, index|
      {
        number: index + 1,
        of: count,
        due_on: base_date.to_date + offset.to_i,
        amount_cents: per + (index == count - 1 ? remainder : 0)
      }
    end
  end

  # Texto curto para listagens.
  def installments_summary
    offsets = installment_offsets
    return "À vista" if offsets.all? { |offset| offset.to_i.zero? }
    return "1× em #{offsets.first}d" if offsets.size == 1

    if day_offsets.present?
      "#{offsets.size}× · #{offsets.join('/')}d"
    else
      "#{offsets.size}× · 1º em #{days.to_i}d · a cada #{interval_days.to_i}d"
    end
  end

  # Aceita "0, 30, 60" no formulário e guarda como array de inteiros.
  def day_offsets_list
    Array(day_offsets).join(", ")
  end

  def day_offsets_list=(value)
    self.day_offsets = value.to_s.split(/[,\s]+/).reject(&:blank?).map(&:to_i)
  end

  private

  def normalize_installment_fields
    self.installments_count = 1 if installments_count.blank?
    self.interval_days = 0 if interval_days.blank?
    self.day_offsets = [] if day_offsets.blank?
  end

  def day_offsets_must_be_non_negative_integers
    return if day_offsets.blank?

    valid = day_offsets.is_a?(Array) &&
            day_offsets.all? { |offset| offset.is_a?(Integer) && offset >= 0 }

    errors.add(:day_offsets, "deve conter apenas números de dias válidos (ex.: 0, 30, 60)") unless valid
  end

  def activity_description
    "Condição de pagamento #{name}"
  end
end
