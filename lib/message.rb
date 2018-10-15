class Message < Base
  def self.mysql_table
    'messages'
  end

  def self.insert(message, type: 'action', speaker: nil, target: nil)
    speaker ||= User.ensure(speaker) || User.new(0)
    target = User.ensure(target) || speaker
    params = {
      x: speaker.x, y: speaker.y, z: speaker.z,
      type: type, message: message,
      speaker_id: speaker.id, target_id: target.id
    }
    mysql_insert(self.mysql_table, **params)
  end

  def self.chats(limit = 30)
    query = 'SELECT * FROM `messages` ' \
            "WHERE `type` = 'chat' AND `speaker_id` != 0 " \
            'ORDER BY `time` DESC ' \
            "LIMIT 0,#{limit}"
    db.query(query).map{|e| Message.new(row: e)}
  end

  def self.for_user(user)
    user = User.ensure(user)
    x = user.x
    y = user.y
    z = user.z
    query = 'SELECT * FROM `messages` WHERE ' +

            # spoken, whispered, game, /me or actions visible to all at same x, y, z
            "((`type` = 'talk' OR `type` = 'whisper' " \
            "OR `type` = 'slash_me' OR `type` = 'game' " \
            "OR `type` = 'visible_all')" \
            "AND `x` = '#{x}' AND `y` = '#{y}' AND `z` = '#{z}' " \
            "AND (`time` + INTERVAL 1 MINUTE) > '#{user.lastaction}')" +

            # shouted or distant at same x, y
            " OR ((`type` = 'shout' OR `type` = 'distant') AND " \
            "`x` = '#{x}' AND `y` = '#{y}'" \
            "AND (`time` + INTERVAL 1 MINUTE) > '#{user.lastaction}')" +

            # action targeted at player
            " OR (`type` = 'action' AND `target_id` = '#{user.mysql_id}'" \
            "AND (`time` + INTERVAL 1 MINUTE) > '#{user.lastaction}')" +

            # persistent messages at same x, y, z
            " OR (`type` = 'persistent' AND " \
            "`x` = '#{x}' AND `y` = '#{y}' AND `z` = '#{z}'" \
            "AND (`time` + INTERVAL 24 HOUR) > '#{user.lastaction}')" \
            ' ORDER BY `time`'

    db.query(query).map{|e| Message.new(row: e)}
  end


  def to_s(user_id = nil)
    desc =
      case msg["type"]
      when "talk"
        "#{you_or_him(user_id, msg["speaker_id"], "You")} said " +
        "<i>\"#{msg["message"]}\"</i>" +
        if msg["target_id"] != "0"
          " to #{you_or_him(user_id, msg["target_id"])}"
        else
          ""
        end
      when "whisper"
        case msg["target_id"]
        when "0"
          if user_id.to_s == msg["speaker_id"]
            "<b>You</b> mumbled something under your breath"
          else
            html_userlink(msg["speaker_id"]) +
            "mumbled something under their breath"
          end
        when user_id.to_s
          "#{html_userlink(msg["speaker_id"])} whispered " +
            "<i>\"#{msg["message"]}\"</i> to <b>you</b>"
        else
          if user_id.to_s == msg["speaker_id"]
            "<b>You</b> whispered <i>\"#{msg["message"]}\"</i> " +
              "to #{html_userlink(msg["target_id"])}"
          else
            "#{html_userlink(msg["speaker_id"])} whispered something " +
              "to #{html_userlink(msg["target_id"])}"
          end
        end
      when "shout"
        you_or_him(user_id, msg["speaker_id"], "You") +
        " shouted <i>\"#{msg["message"]}\"</i>" +
        if msg["target_id"] != "0"
          " to #{you_or_him(user_id, msg["target_id"])}"
        else ""       end
      when "game"
        msg["message"]
      when "distant"
        "Someone nearby shouted <i>\"#{msg["message"]}\"</i>"
      when "persistent"
        insert_names(msg["message"], msg["speaker_id"].to_i, msg["target_id"].to_i, user_id)
      when "action"
        insert_names(msg["message"], msg["speaker_id"].to_i, msg["target_id"].to_i, user_id)
      when "slash_me"
        insert_names(msg["message"], msg["speaker_id"].to_i, msg["target_id"].to_i, user_id)
      when "visible_all"
        insert_names(msg["message"], msg["speaker_id"].to_i, msg["target_id"].to_i, user_id)
      when "chat"
        html_userlink(msg["speaker_id"]) + ": " + msg["message"]
      else
        return ""
      end
    desc + "<span class=\"time\"> " +
      "#{Time.str_to_time(msg["time"]).ago}.</span>"
  end


end