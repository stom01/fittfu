class TeamGame < ActiveRecord::Base
  belongs_to :game, inverse_of: :team_games
  belongs_to :team
  has_many :game_stats, dependent: :destroy

  validates :game_id, presence: true
  validates :team_id, presence: true, uniqueness: { scope: :game_id }

  after_save :create_game_stats

  def create_game_stats
    team.players.pluck(:id).each do |player_id|
      self.game_stats.create(player_id: player_id, week: self.game.week)
    end
  end
end
