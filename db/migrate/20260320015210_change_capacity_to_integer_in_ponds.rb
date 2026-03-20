class ChangeCapacityToIntegerInPonds < ActiveRecord::Migration[7.1]
  def up
    # Converte valores existentes (ex: 7000.0 -> 7000)
    execute <<-SQL
      UPDATE ponds
      SET capacity = FLOOR(capacity)
      WHERE capacity IS NOT NULL
    SQL

    # Altera o tipo da coluna
    change_column :ponds, :capacity, :integer, using: "capacity::integer"
  end

  def down
    change_column :ponds, :capacity, :decimal
  end
end
