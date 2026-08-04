require "rails_helper"

RSpec.describe "FeedingStrategyItems", type: :request do
  let(:user) { create(:user) }
  let(:feeding_table) { create(:feeding_table) }
  let(:weight_range) { create(:feeding_weight_range) }
  let(:temperature_range) { create(:feeding_temperature_range) }

  before { sign_in user }

  describe "POST /feeding_tables/:feeding_table_id/feeding_strategy_items" do
    it "creates a percentage cell for the weight/temperature combination" do
      expect do
        post feeding_table_feeding_strategy_items_path(feeding_table), params: {
          feeding_strategy_item: {
            feeding_weight_range_id: weight_range.id,
            feeding_temperature_range_id: temperature_range.id,
            feeding_percentage: 3.5
          }
        }
      end.to change(FeedingStrategyItem, :count).by(1)

      expect(response).to redirect_to(edit_feeding_table_path(feeding_table))
    end

    it "updates the existing cell instead of duplicating it" do
      create(:feeding_strategy_item,
        feeding_table: feeding_table,
        feeding_weight_range: weight_range,
        feeding_temperature_range: temperature_range,
        feeding_percentage: 2.0)

      expect do
        post feeding_table_feeding_strategy_items_path(feeding_table), params: {
          feeding_strategy_item: {
            feeding_weight_range_id: weight_range.id,
            feeding_temperature_range_id: temperature_range.id,
            feeding_percentage: 4.0
          }
        }
      end.not_to change(FeedingStrategyItem, :count)

      expect(feeding_table.feeding_strategy_items.first.feeding_percentage.to_f).to eq(4.0)
    end
  end

  describe "DELETE /feeding_tables/:feeding_table_id/feeding_strategy_items/:id" do
    it "removes the cell" do
      item = create(:feeding_strategy_item, feeding_table: feeding_table)

      expect do
        delete feeding_table_feeding_strategy_item_path(feeding_table, item)
      end.to change(FeedingStrategyItem, :count).by(-1)

      expect(response).to redirect_to(edit_feeding_table_path(feeding_table))
    end
  end
end
