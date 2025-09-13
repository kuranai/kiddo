class MultimediaAllowance < ApplicationRecord
  belongs_to :user

  validates :monday_minutes, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 480 }
  validates :tuesday_minutes, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 480 }
  validates :wednesday_minutes, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 480 }
  validates :thursday_minutes, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 480 }
  validates :friday_minutes, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 480 }
  validates :saturday_minutes, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 480 }
  validates :sunday_minutes, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 480 }
  validates :max_bonus_minutes, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 180 }
  validates :bonus_time_enabled, inclusion: { in: [true, false] }

  # Get allowance for a specific day of the week (0=Sunday, 1=Monday, etc.)
  def minutes_for_day(day_of_week)
    case day_of_week
    when 0 then sunday_minutes
    when 1 then monday_minutes
    when 2 then tuesday_minutes
    when 3 then wednesday_minutes
    when 4 then thursday_minutes
    when 5 then friday_minutes
    when 6 then saturday_minutes
    else
      raise ArgumentError, "Invalid day of week: #{day_of_week}"
    end
  end

  # Set allowance for a specific day of the week
  def set_minutes_for_day(day_of_week, minutes)
    case day_of_week
    when 0 then self.sunday_minutes = minutes
    when 1 then self.monday_minutes = minutes
    when 2 then self.tuesday_minutes = minutes
    when 3 then self.wednesday_minutes = minutes
    when 4 then self.thursday_minutes = minutes
    when 5 then self.friday_minutes = minutes
    when 6 then self.saturday_minutes = minutes
    else
      raise ArgumentError, "Invalid day of week: #{day_of_week}"
    end
  end

  # Get today's allowance in minutes
  def todays_base_allowance
    minutes_for_day(Date.current.wday)
  end

  # Get weekly total allowance
  def weekly_total_minutes
    monday_minutes + tuesday_minutes + wednesday_minutes + thursday_minutes +
      friday_minutes + saturday_minutes + sunday_minutes
  end

  # Get weekday vs weekend breakdown
  def weekday_total_minutes
    monday_minutes + tuesday_minutes + wednesday_minutes + thursday_minutes + friday_minutes
  end

  def weekend_total_minutes
    saturday_minutes + sunday_minutes
  end

  # Check if bonus time is available for today
  def bonus_available_today?
    bonus_time_enabled? && max_bonus_minutes > 0
  end

  # Bulk update all weekdays (Monday-Friday)
  def update_weekdays(minutes)
    update!(
      monday_minutes: minutes,
      tuesday_minutes: minutes,
      wednesday_minutes: minutes,
      thursday_minutes: minutes,
      friday_minutes: minutes
    )
  end

  # Bulk update weekend (Saturday-Sunday)
  def update_weekend(minutes)
    update!(
      saturday_minutes: minutes,
      sunday_minutes: minutes
    )
  end

  # Get a human-readable schedule summary
  def schedule_summary
    {
      weekdays: weekday_total_minutes / 5, # Average weekday time
      weekend: weekend_total_minutes / 2,  # Average weekend time
      weekly_total: weekly_total_minutes,
      bonus_enabled: bonus_time_enabled?,
      max_bonus: max_bonus_minutes
    }
  end
end