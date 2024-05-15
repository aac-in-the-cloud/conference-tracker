class FeedWeek < ApplicationRecord
  before_save :generate_defaults

  def generate_defaults
  end

  def session_records
    ids = (self.sessions || "").split(',')
    ids_hash = {}
    ids.each_with_index{|id, idx| ids_hash[id] = idx }
    res = []
    ConferenceSession.where(id: ids).each do |s|
      if ids_hash[s.id] && !res[ids_hash[s.id]]
        res[ids_hash[s.id]] = s
      else
        res << s
      end
    end
    res
  end

  def self.current_for(cat, allow_new_category=false)
    currweek = Time.now.to_date.cweek
    curryear = Time.now.year
    weeks = FeedWeek.where(week: currweek, category: cat).order('year DESC')
    week = weeks[0]
    return week if week && week.year == curryear
    return nil if !allow_new_category && cat != 'all' && FeedWeek.where(category: cat).count == 0

    week = FeedWeek.new(week: currweek, year: curryear, category: cat)
    id_years = {}
    weeks.each do |w|
      ss = w.sessions.split(/,/)
      ss.each do |s|
        id_years[s] ||= w.year
      end
    end
    results = ConferenceSession.order("ABS(MOD(id, 52) - #{currweek - 1}) ASC, id DESC")
    mod = 52
    mod_results = []
    while mod_results.length == 0 && mod > 10
      mod_results = results.select{|s| (s.id % mod) == ((currweek - 1) % mod)}
      mod = mod / 2
    end
    results = mod_results[0, 100]
    results = results.select{|s| s.active? && s.for_category?(cat) }
    results = results.sort_by do |s|
      score = 0
      data = JSON.parse(s.data) rescue nil
      data ||= {}
      # overall rating: 10 pts
      score += (data['average_score'] || 0.0) * 2.0
      # total views: 10 pts
      score += [(data['views'] || 0), 1000].min / 100
      # year they were released: 10 pts
      score += 10 - [curryear - Time.at(s.zoned_timestamp || 0).year, 10].min
      # years since they were included in the week's feed: 30 pts
      score += [10, curryear - (id_years[s.id] || 0)].min * 3
      score
    end.reverse
    week.sessions = results[0, 3].map(&:id).join(',')
    week.save
    week
  end
end
