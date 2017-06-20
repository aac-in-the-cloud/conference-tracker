class CreateSurveyResults < ActiveRecord::Migration[5.0]
  def change
    create_table :survey_results do |t|
      t.text :data
      t.string :email_hash
      t.string :code
      t.timestamps
    end
    add_index :survey_results, [:code, :email_hash], :unique => true
  end
end
