class GameStat < ActiveRecord::Base
  FIELDS = %w(Ds Goals Assists Turns Swag)

  belongs_to :player
  belongs_to :team_game
  has_one :team, through: :player
  has_one :game, through: :team_game

  validates :team_game_id, presence: true
  validates :player_id, presence: true, uniqueness: { scope: :team_game_id }

  before_update :update_points
  before_destroy :remove_points

  TYPE = %i(goals assists ds turns swag)
  SCORE = [3, 3, 2, -1, 1]
  VALUE = {"goals": 3, "assists": 3, "ds":2, "turns":-1, "swag":1}

  COUNT = TYPE.zip(SCORE)

  def update_points
    team_game.update_attributes(goals: team_game.goals + (goals - goals_was)) if goals_changed?
    prior_points = self[:points]
    self[:points] = COUNT.inject(0) { |sum, obj| sum + self[obj[0]] * obj[1] }
    player.update_attribute(:points, player.points + points - prior_points)
    # change updating winners in future
    AssignWinners.perform_in(30*60, false) if goals < 2
  end

  def remove_points
    player.update_attribute(:points, player.points - points) unless player.blank?
  end
end
