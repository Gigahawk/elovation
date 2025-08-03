class ResultService
  def self.create(game, params)
    result = game.results.build

    next_rank = Team::FIRST_PLACE_RANK
    teams = (params[:teams] || {}).values.each.with_object([]) do |team, acc|
      players = Array.wrap(team[:players]).delete_if(&:blank?)
      acc << { rank: next_rank, players: players }

      next_rank = next_rank + 1 if team[:relation] != "ties"
    end

    teams = teams.reverse.drop_while{ |team| team[:players].empty? }.reverse

    teams.each do |team|
      result.teams.build rank: team[:rank], player_ids: team[:players]
    end

    # Use the datetime picker value to set created_at
    # Rails datetime_select sends a hash of date parts, not a Time object
    # This seems super hacky, is there a better way?
    year  = params["created_at(1i)"].to_i
    month = params["created_at(2i)"].to_i
    day   = params["created_at(3i)"].to_i
    hour  = params["created_at(4i)"].to_i
    min   = params["created_at(5i)"].to_i
    parsed_time = Time.zone.local(year, month, day, hour, min)
    Result.record_timestamps = false
    result.created_at = parsed_time
    result.updated_at = Time.now

    if result.valid?
      Result.transaction do
        game.rater.update_ratings game, result.teams
        result.save!
        Result.record_timestamps = true
        OpenStruct.new(
          success?: true,
          result: result
        )
      end
    else
      Result.record_timestamps = true
      OpenStruct.new(
        success?: false,
        result: result
      )
    end
  end

  def self.destroy(result)
    return OpenStruct.new(success?: false) unless result.most_recent?

    Result.transaction do
      result.players.each do |player|
        player.rewind_rating!(result.game)
      end

      result.destroy

      OpenStruct.new(success?: true)
    end
  end
end