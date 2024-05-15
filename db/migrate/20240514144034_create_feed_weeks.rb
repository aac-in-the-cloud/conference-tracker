class CreateFeedWeeks < ActiveRecord::Migration[5.0]
  def change
    create_table :feed_weeks do |t|
      t.integer :week
      t.integer :year
      t.string :category
      t.string :sessions
    end
    add_index :feed_weeks, [:week, :year]
  end
end
