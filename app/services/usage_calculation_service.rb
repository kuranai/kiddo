class UsageCalculationService
  class << self
    # Calculate comprehensive daily usage statistics for a user
    def calculate_daily_stats(user, date = Date.current)
      usage_record = DailyUsage.for_user_on_date(user, date)
      sessions = user.multimedia_sessions.for_date(date)
      allowance = user.ensure_multimedia_allowance

      # Base statistics
      stats = {
        date: date,
        user_name: user.name,
        base_allowance: allowance.minutes_for_day(date.wday),
        bonus_earned: usage_record.bonus_minutes_earned,
        total_available: usage_record.total_available_minutes,
        total_used: usage_record.actual_total_used,
        regular_used: usage_record.total_minutes_used,
        bonus_used: usage_record.bonus_minutes_used,
        remaining: usage_record.remaining_minutes,
        usage_percentage: usage_record.usage_percentage,
        session_count: sessions.count,
        active_session: sessions.active.exists?
      }

      # Session breakdown
      stats[:sessions] = {
        regular_sessions: sessions.regular.count,
        bonus_sessions: sessions.bonus.count,
        emergency_sessions: sessions.emergency.count,
        average_session_length: sessions.completed.average(:duration_minutes)&.to_f&.round(1) || 0,
        longest_session: sessions.maximum(:duration_minutes) || 0,
        shortest_session: sessions.completed.minimum(:duration_minutes) || 0
      }

      # Time analysis
      stats[:time_analysis] = analyze_usage_patterns(sessions)

      # Comparison with previous day
      yesterday_stats = calculate_daily_stats(user, date - 1.day) if date > Date.current - 30.days
      if yesterday_stats
        stats[:comparison] = {
          usage_change: stats[:total_used] - yesterday_stats[:total_used],
          percentage_change: calculate_percentage_change(yesterday_stats[:total_used], stats[:total_used]),
          session_count_change: stats[:session_count] - yesterday_stats[:session_count]
        }
      end

      stats
    end

    # Calculate weekly usage statistics
    def calculate_weekly_stats(user, start_date = Date.current.beginning_of_week)
      end_date = start_date.end_of_week
      daily_usages = user.daily_usages.where(usage_date: start_date..end_date).includes(:user)
      sessions = user.multimedia_sessions.joins(:user).where(started_at: start_date.beginning_of_day..end_date.end_of_day)

      stats = {
        week_start: start_date,
        week_end: end_date,
        user_name: user.name,
        total_days: 7,
        recorded_days: daily_usages.count
      }

      # Aggregate statistics
      stats[:totals] = {
        total_allowed: daily_usages.sum(:total_minutes_allowed),
        total_used: daily_usages.sum(:total_minutes_used),
        bonus_earned: daily_usages.sum(:bonus_minutes_earned),
        bonus_used: daily_usages.sum(:bonus_minutes_used),
        total_sessions: sessions.count,
        days_exhausted: daily_usages.where(remaining_minutes: 0).count
      }

      # Daily breakdown
      stats[:daily_breakdown] = daily_usages.order(:usage_date).map do |usage|
        {
          date: usage.usage_date,
          day_name: usage.usage_date.strftime("%A"),
          allowed: usage.total_minutes_allowed,
          used: usage.actual_total_used,
          remaining: usage.remaining_minutes,
          percentage: usage.usage_percentage,
          exhausted: usage.remaining_minutes == 0
        }
      end

      # Averages and patterns
      stats[:averages] = calculate_weekly_averages(daily_usages, sessions)
      stats[:patterns] = analyze_weekly_patterns(daily_usages)

      stats
    end

    # Calculate monthly usage statistics
    def calculate_monthly_stats(user, month_start = Date.current.beginning_of_month)
      month_end = month_start.end_of_month
      daily_usages = user.daily_usages.where(usage_date: month_start..month_end)
      sessions = user.multimedia_sessions.where(started_at: month_start.beginning_of_day..month_end.end_of_day)

      stats = {
        month: month_start.strftime("%B %Y"),
        user_name: user.name,
        total_days: (month_end - month_start + 1).to_i,
        recorded_days: daily_usages.count
      }

      # Monthly totals
      stats[:totals] = {
        total_allowed: daily_usages.sum(:total_minutes_allowed),
        total_used: daily_usages.sum(:total_minutes_used),
        bonus_earned: daily_usages.sum(:bonus_minutes_earned),
        bonus_used: daily_usages.sum(:bonus_minutes_used),
        total_sessions: sessions.count
      }

      # Weekly breakdown within the month
      stats[:weekly_breakdown] = []
      current_week_start = month_start.beginning_of_week

      while current_week_start <= month_end
        week_end = [current_week_start.end_of_week, month_end].min
        week_usages = daily_usages.where(usage_date: current_week_start..week_end)

        stats[:weekly_breakdown] << {
          week_start: current_week_start,
          week_end: week_end,
          total_used: week_usages.sum(:total_minutes_used),
          total_allowed: week_usages.sum(:total_minutes_allowed),
          average_daily: week_usages.average(:total_minutes_used)&.to_f&.round(1) || 0
        }

        current_week_start = week_end + 1.day
      end

      # Month-over-month comparison
      previous_month_stats = calculate_monthly_stats(user, month_start - 1.month)
      if previous_month_stats
        stats[:comparison] = {
          usage_change: stats[:totals][:total_used] - previous_month_stats[:totals][:total_used],
          percentage_change: calculate_percentage_change(previous_month_stats[:totals][:total_used], stats[:totals][:total_used])
        }
      end

      stats
    end

    # Generate family-wide usage report
    def generate_family_report(date_range = 7.days)
      end_date = Date.current
      start_date = end_date - date_range

      family_stats = {
        date_range: "#{start_date} to #{end_date}",
        total_days: date_range.to_i + 1,
        generated_at: Time.current
      }

      # Get all users with usage data
      users_with_usage = User.joins(:daily_usages)
                            .where(daily_usages: { usage_date: start_date..end_date })
                            .distinct
                            .includes(:daily_usages, :multimedia_sessions)

      family_stats[:user_count] = users_with_usage.count
      family_stats[:user_stats] = []

      total_family_usage = 0
      total_family_allowance = 0

      users_with_usage.each do |user|
        user_usages = user.daily_usages.where(usage_date: start_date..end_date)

        user_stat = {
          user_name: user.name,
          user_role: user.role,
          total_used: user_usages.sum(:total_minutes_used),
          total_allowed: user_usages.sum(:total_minutes_allowed),
          total_sessions: user.multimedia_sessions.where(started_at: start_date.beginning_of_day..end_date.end_of_day).count,
          average_daily_usage: user_usages.average(:total_minutes_used)&.to_f&.round(1) || 0,
          days_exhausted: user_usages.where(remaining_minutes: 0).count,
          efficiency_score: calculate_usage_efficiency(user_usages)
        }

        total_family_usage += user_stat[:total_used]
        total_family_allowance += user_stat[:total_allowed]

        family_stats[:user_stats] << user_stat
      end

      # Family-wide aggregates
      family_stats[:family_totals] = {
        total_usage: total_family_usage,
        total_allowance: total_family_allowance,
        family_efficiency: calculate_percentage_change(0, total_family_usage.to_f / total_family_allowance * 100).round(1),
        highest_user: family_stats[:user_stats].max_by { |u| u[:total_used] }&.dig(:user_name),
        most_efficient_user: family_stats[:user_stats].max_by { |u| u[:efficiency_score] }&.dig(:user_name)
      }

      family_stats
    end

    # Calculate usage trends over time
    def calculate_usage_trends(user, days = 30)
      end_date = Date.current
      start_date = end_date - days.days

      daily_usages = user.daily_usages
                        .where(usage_date: start_date..end_date)
                        .order(:usage_date)

      trends = {
        period: "#{start_date} to #{end_date}",
        total_days: days + 1,
        data_points: daily_usages.count
      }

      # Daily data points
      trends[:daily_data] = daily_usages.map do |usage|
        {
          date: usage.usage_date,
          used: usage.actual_total_used,
          allowed: usage.total_available_minutes,
          percentage: usage.usage_percentage,
          efficiency: calculate_daily_efficiency(usage)
        }
      end

      # Trend analysis
      if trends[:daily_data].length > 1
        usage_values = trends[:daily_data].map { |d| d[:used] }
        trends[:trend_analysis] = {
          overall_trend: calculate_trend_direction(usage_values),
          average_usage: usage_values.sum.to_f / usage_values.length,
          peak_usage_day: trends[:daily_data].max_by { |d| d[:used] }[:date],
          lowest_usage_day: trends[:daily_data].min_by { |d| d[:used] }[:date],
          most_consistent_week: find_most_consistent_week(trends[:daily_data])
        }
      end

      trends
    end

    # Calculate bonus time optimization suggestions
    def calculate_bonus_suggestions(user)
      recent_todos = user.assigned_todos
                        .where(created_at: 30.days.ago..Time.current)
                        .includes(:point_transactions)

      allowance = user.ensure_multimedia_allowance
      recent_usage = user.daily_usages.where(usage_date: 30.days.ago..Date.current)

      suggestions = {
        user_name: user.name,
        current_bonus_enabled: allowance.bonus_time_enabled?,
        max_bonus_minutes: allowance.max_bonus_minutes,
        analysis_period: "Last 30 days"
      }

      # Todo completion analysis
      completed_todos = recent_todos.completed
      suggestions[:todo_analysis] = {
        total_todos: recent_todos.count,
        completed_count: completed_todos.count,
        completion_rate: completed_todos.count.to_f / [recent_todos.count, 1].max * 100,
        average_points_per_todo: completed_todos.average(:points)&.to_f&.round(1) || 0,
        potential_bonus_minutes: calculate_potential_bonus_time(completed_todos)
      }

      # Usage pattern analysis
      high_usage_days = recent_usage.where('remaining_minutes <= ?', 15).count
      suggestions[:usage_analysis] = {
        high_usage_days: high_usage_days,
        average_remaining: recent_usage.average(:remaining_minutes)&.to_f&.round(1) || 0,
        bonus_time_needed_days: high_usage_days,
        optimal_bonus_minutes: calculate_optimal_bonus_minutes(recent_usage)
      }

      # Recommendations
      suggestions[:recommendations] = generate_bonus_recommendations(suggestions)

      suggestions
    end

    private

    # Analyze usage patterns within a day
    def analyze_usage_patterns(sessions)
      return {} if sessions.empty?

      patterns = {}

      # Time of day analysis
      hourly_usage = sessions.completed.group("strftime('%H', started_at)").sum(:duration_minutes)
      if hourly_usage.any?
        peak_hour = hourly_usage.max_by { |hour, minutes| minutes }&.first
        patterns[:peak_usage_hour] = "#{peak_hour}:00" if peak_hour
      end

      # Session length analysis
      durations = sessions.completed.pluck(:duration_minutes)
      if durations.any?
        patterns[:average_session_length] = durations.sum.to_f / durations.length
        patterns[:session_length_consistency] = calculate_consistency_score(durations)
      end

      patterns
    end

    # Calculate weekly averages
    def calculate_weekly_averages(daily_usages, sessions)
      return {} if daily_usages.empty?

      {
        daily_usage: daily_usages.average(:total_minutes_used)&.to_f&.round(1) || 0,
        daily_allowance: daily_usages.average(:total_minutes_allowed)&.to_f&.round(1) || 0,
        daily_sessions: sessions.count.to_f / 7,
        utilization_rate: (daily_usages.sum(:total_minutes_used).to_f / daily_usages.sum(:total_minutes_allowed) * 100).round(1)
      }
    end

    # Analyze weekly patterns
    def analyze_weekly_patterns(daily_usages)
      return {} if daily_usages.empty?

      # Group by day of week
      by_weekday = daily_usages.group_by { |usage| usage.usage_date.wday }

      patterns = {}
      by_weekday.each do |wday, usages|
        day_name = Date::DAYNAMES[wday]
        avg_usage = usages.sum(&:total_minutes_used).to_f / usages.length
        patterns["#{day_name.downcase}_average"] = avg_usage.round(1)
      end

      # Find patterns
      weekend_avg = [(patterns["saturday_average"] || 0), (patterns["sunday_average"] || 0)].sum / 2
      weekday_avg = [1,2,3,4,5].map { |d| patterns["#{Date::DAYNAMES[d].downcase}_average"] || 0 }.sum / 5

      patterns[:weekend_vs_weekday_ratio] = weekend_avg / [weekday_avg, 1].max
      patterns[:highest_usage_day] = patterns.except(:weekend_vs_weekday_ratio).max_by { |k,v| v }&.first
      patterns[:lowest_usage_day] = patterns.except(:weekend_vs_weekday_ratio).min_by { |k,v| v }&.first

      patterns
    end

    # Calculate percentage change between two values
    def calculate_percentage_change(old_value, new_value)
      return 0 if old_value == 0 && new_value == 0
      return 100 if old_value == 0
      ((new_value - old_value).to_f / old_value * 100).round(1)
    end

    # Calculate usage efficiency (how well time is utilized vs wasted)
    def calculate_usage_efficiency(daily_usages)
      return 0 if daily_usages.empty?

      total_available = daily_usages.sum(&:total_available_minutes)
      total_used = daily_usages.sum(&:actual_total_used)
      return 0 if total_available == 0

      (total_used.to_f / total_available * 100).round(1)
    end

    # Calculate daily efficiency score
    def calculate_daily_efficiency(usage)
      return 0 if usage.total_available_minutes == 0

      # Factor in both usage and not going over
      base_efficiency = (usage.actual_total_used.to_f / usage.total_available_minutes * 100).round(1)

      # Bonus for using bonus time earned
      bonus_efficiency = if usage.bonus_minutes_earned > 0
        (usage.bonus_minutes_used.to_f / usage.bonus_minutes_earned * 100).round(1)
      else
        100
      end

      # Weighted average
      (base_efficiency * 0.7 + bonus_efficiency * 0.3).round(1)
    end

    # Calculate trend direction from a series of values
    def calculate_trend_direction(values)
      return :stable if values.length < 2

      # Simple linear trend calculation
      n = values.length
      sum_x = (1..n).sum
      sum_y = values.sum
      sum_xy = values.each_with_index.sum { |y, i| y * (i + 1) }
      sum_x2 = (1..n).sum { |x| x * x }

      slope = (n * sum_xy - sum_x * sum_y).to_f / (n * sum_x2 - sum_x * sum_x)

      if slope > 0.5
        :increasing
      elsif slope < -0.5
        :decreasing
      else
        :stable
      end
    end

    # Find the most consistent week in the data
    def find_most_consistent_week(daily_data)
      return nil if daily_data.length < 7

      weeks = []
      (0..daily_data.length-7).each do |start_idx|
        week_data = daily_data[start_idx, 7]
        usage_values = week_data.map { |d| d[:used] }
        consistency = calculate_consistency_score(usage_values)
        weeks << {
          start_date: week_data.first[:date],
          end_date: week_data.last[:date],
          consistency_score: consistency,
          average_usage: usage_values.sum.to_f / usage_values.length
        }
      end

      weeks.max_by { |w| w[:consistency_score] }
    end

    # Calculate consistency score (lower variance = higher consistency)
    def calculate_consistency_score(values)
      return 100 if values.length <= 1

      mean = values.sum.to_f / values.length
      variance = values.sum { |v| (v - mean) ** 2 } / values.length
      std_dev = Math.sqrt(variance)

      # Convert to a 0-100 scale where 100 is most consistent
      max_possible_dev = values.max - values.min
      return 100 if max_possible_dev == 0

      consistency = [100 - (std_dev / max_possible_dev * 100), 0].max
      consistency.round(1)
    end

    # Calculate potential bonus time from completed todos
    def calculate_potential_bonus_time(completed_todos)
      # Simple conversion: 1 point = 1 minute of bonus time
      # This could be made configurable
      completed_todos.sum(:points)
    end

    # Calculate optimal bonus minutes based on usage patterns
    def calculate_optimal_bonus_minutes(recent_usage)
      # Find days where user ran out of time but could have used more
      deficit_days = recent_usage.where(remaining_minutes: 0)
      return 0 if deficit_days.empty?

      # Calculate average deficit (how much more time would be ideal)
      average_total_used = recent_usage.average(:total_minutes_used) || 0
      average_allowance = recent_usage.average(:total_minutes_allowed) || 0

      optimal = [(average_total_used - average_allowance) * 1.2, 30].max
      [optimal.to_i, 120].min  # Cap at 2 hours
    end

    # Generate personalized bonus recommendations
    def generate_bonus_recommendations(analysis)
      recommendations = []

      todo_analysis = analysis[:todo_analysis]
      usage_analysis = analysis[:usage_analysis]

      # Todo completion recommendations
      if todo_analysis[:completion_rate] < 70
        recommendations << {
          type: :todo_improvement,
          priority: :high,
          message: "Focus on completing more todos to earn bonus time. Current completion rate: #{todo_analysis[:completion_rate].round(1)}%"
        }
      end

      # Bonus time settings recommendations
      if usage_analysis[:high_usage_days] > 7 && analysis[:max_bonus_minutes] < usage_analysis[:optimal_bonus_minutes]
        recommendations << {
          type: :increase_bonus_limit,
          priority: :medium,
          message: "Consider increasing bonus time limit to #{usage_analysis[:optimal_bonus_minutes]} minutes based on usage patterns"
        }
      end

      # Time management recommendations
      if usage_analysis[:average_remaining] < 5
        recommendations << {
          type: :time_management,
          priority: :medium,
          message: "You often use most of your daily allowance. Try shorter, more frequent sessions for better balance"
        }
      end

      recommendations
    end
  end
end