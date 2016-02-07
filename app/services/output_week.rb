require "google/api_client"
require "google_drive"

class OutputWeek
  # arguments: google auth token, week (starting at 0)
  def self.write(token, week)
    session = GoogleDrive.login_with_oauth(token)

    file = session.spreadsheet_by_key("1myvP8Bgdx7plek-gX38GvNVsUztj8EMPY76ckNuax-k")
    #coordinate system starts at 1
    teams = Team.all
    teams.each do |t|
      sheet = file.worksheet_by_title(t.captain.name)
      players = t.players
      y = 2
      emen = true
      while !sheet[y, 1].blank? || emen do
        emen = false if sheet[y, 1].blank?
        p = players.find_by(name: sheet[y, 1])
        sheet[y, week + 1 + 1] = p.game_stats.find_by(week: week).points if !p.blank? && sheet[y, week + 1 + 1].blank?
        y += 1
      end
      sheet.save
      p "finished #{t.name}"
    end

    sheet = file.worksheet_by_title("GAME SCHEDULE")
    team_games = TeamGame.where(game_id: Game.where(week: week).pluck(:id))
    x = 1
    y = 1
    time = Game.find_by(week: week).time.to_s(:slashes)
    while sheet[y, x] != time do
      y+= 1
    end
    x = 2
    y += 1
    Team::STD_SIZE.times do
      team_name = sheet[y, x]
      team = Team.find_by(name: team_name)
      sheet[y, x] = "#{team_name} (#{team_games.find_by(team_id: team.id).points})" unless team.blank?
      x = x > 2 ? 2 : 3
      y += 1 if x > 2
    end
    sheet.save
  end
end