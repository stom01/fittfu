class GamesController < ApplicationController
  before_filter :authenticate_user!

  def index
    if !params[:week].blank?
      @games = Game.where(week: params[:week]).default.includes(:teams)
    elsif params[:time] == "past"
      @games = Game.past.default.includes(:teams)
    elsif params[:time] == "upcoming"
      @games = Game.upcoming.default.includes(:teams)
    elsif params[:time] == "all"
      @games = Game.all.default.includes(:teams)
    else
      @games = Game.current.default.includes(:teams)
      @games = Game.past.order(:time).limit(4) if @games.blank?
    end
    #authorize @games
  end

  def new
    authorize Game.new
  end

  def new_week
    authorize Game.new
    @schedule = Schedule.find_by(id: params[:schedule_id])
    if @schedule
      @games = Game.where(time: @schedule.start_time.beginning_of_day..@schedule.start_time.end_of_day)
    end
    @teams = Team.all
  end

  def create_week
    authorize Game.new
    @games = Game.where(week: params[:game][:week])
    if @games.blank?
      Schedule::GAMES_IN_NIGHT.times do |i|
        params[:game][:time_slot] = i
        params[:game][:time] = Time.zone.parse(params[:time][i.to_s])
        @game = Game.new(game_params)
        if @game.save
          create_team_game(params[:slot][i.to_s][:home_id])
          create_team_game(params[:slot][i.to_s][:away_id])
        else
          flash[:error] = "Oops, couldn't create create games for week: #{params[:game][:week] + 1}"
          redirect_to :back
          return
        end
      end
    else
      Schedule::GAMES_IN_NIGHT.times do |i|
        params[:game][:time] = Time.zone.parse(params[:time][i.to_s])
        @game = @games.find_by(time_slot: i)
        @game.update(game_params)
        ids = [params[:slot][i.to_s][:home_id], params[:slot][i.to_s][:away_id]]
        found = 0
        found += 1 unless @game.team_games.find_by(team_id: ids[0]).blank?
        found += 2 unless @game.team_games.find_by(team_id: ids[1]).blank?
        next if @game.team_games.where(team_id: ids).size == 2
        if found == 1
          @game.team_games.where.not(team_id: ids[0]).first.destroy
          create_team_game(ids[1])
        elsif found == 2
          @game.team_games.where.not(team_id: ids[1]).first.destroy
          create_team_game(ids[0])
        elsif found == 0
          @game.team_games.destroy_all
          create_team_game(ids[0])
          create_team_game(ids[1])
        end
      end
    end
    redirect_to games_path({params: {week: params[:game][:week]}})
  end

  def create
    @game = Game.new(game_params)
    authorize @game
    if @game.save
      create_team_game(params[:home_team][:team_id])
      create_team_game(params[:away_team][:team_id])
      redirect_to @game
    else
      flash[:error] =  "Error: could not create game"
      redirect_to new_game_path
    end
  end

  def update_score
    @game = Game.find_by(id: params[:id])
    authorize @game
    if @game
      @game.team_games.find_by(id: params[:home][:id]).update_attribute(:goals, params[:home][:goals])
      @game.team_games.find_by(id: params[:away][:id]).update_attribute(:goals, params[:away][:goals])
      AssignWinners.perform_async(false)
      redirect_to scorekeep_games_path(@game)
    else
      redirect_to games_path
    end
  end

  def show
    @game = Game.find_by(id: params[:id])
    authorize @game
  end

  def scorekeep
    @game = Game.find_by(id: params[:id])
    authorize @game
  end

  def create_schedule
    authorize Game.new
    if Schedule.for(Time.zone.now.year).any?
      if MakeSchedule.build.call
        redirect_to games_path
      else
        flash[:error] = "Games already created or not enough teams were made yet"
        redirect_to root_path
      end
    else
      flash[:error] = "Please add game times first"
      redirect_to root_path
    end

  end

  # TODO Remove for production
  def delete_all
    Game.destroy_all unless Game.first.blank?
    redirect_to games_path
  end

  def destroy
    @game = Game.find_by(id: params[:id])
    authorize @game
    if @game
      flash[:alert] = @game.has_teams? ? "Deleted game between #{@game.teams.first.name} and #{@game.teams.second.name}, week: #{@game.week + 1}, timeslot: #{@game.time_slot + 1}"
                        : "Deleted game on week #{@game.week + 1}, timeslot: #{@game.time_slot +1}"
      @game.destroy
    else
      flash[:error] = "Could not find game with id: #{params[:id]}"
    end
    redirect_to games_path
  end

  private

  def create_team_game(team_id)
    team_game = @game.team_games.build(team_id: team_id)
    if team_game.save
      return true
    else
      p "Error: could not create team_game"
      return false
    end
  end

  def game_params
    params.require(:game).permit(:week, :time_slot, :time)
  end
end
