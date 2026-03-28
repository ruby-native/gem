class CreateRubyNativePurchaseIntents < ActiveRecord::Migration[7.1]
  def change
    create_table :ruby_native_purchase_intents do |t|
      t.string :uuid, null: false
      t.string :customer_id, null: false
      t.string :product_id
      t.string :success_path
      t.string :status, null: false, default: "pending"
      t.string :environment

      t.timestamps
    end

    add_index :ruby_native_purchase_intents, :uuid, unique: true
    add_index :ruby_native_purchase_intents, :customer_id
  end
end
