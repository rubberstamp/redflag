class CsvUpload < ApplicationRecord
  has_one_attached :file
  
  # Add validation to ensure only CSVs are attached
  validate :acceptable_file
  
  # Add a session_id field to help track uploads
  validates :session_id, presence: true
  
  private
  
  def acceptable_file
    return unless file.attached?
    
    unless file.content_type == "text/csv" || 
           file.filename.to_s.ends_with?(".csv")
      errors.add(:file, "must be a CSV file")
    end
  end
end