puts <<~ENDTEXT
  <html>

  <head profile="http://www.w3.org/2005/10/profile">
  <link rel="icon"
        type="image/png"
        href="images/favicon.ico">
  <title>Shintolin - Explore. Settle. Trade. Conquer.</title>
  <link rel="stylesheet" type="text/css" href="/html/shintolin.css" />
  </head>
  <body>
  <div class="bigbox">

  <div class="map">
  #{Location_Bar}
  #{Map}
  </div>

  <div class="gamebox statsbox">
  #{Player_Data}
  </div>

  <div class="gamebox buttonsbox">
    <a class="buttonlink" href="skills.cgi">Skills</a>
    <a class="buttonlink" href="map.cgi">Map</a>
    <a class="buttonlink" href="contacts.cgi">Contacts</a>
    <a class="buttonlink" href="rankings.cgi">Rankings</a>
    <a class="buttonlink" href="/html/faq.html">FAQ</a>
ENDTEXT
puts "<a class=\"admin buttonlink\" href=\"/edit-map.cgi?x=#{current_user.x}&y=#{current_user.y}\">Edit Map</a>" if current_user.is_admin?
puts <<~ENDTEXT
    #{Logout_Button}

  </div>

  <table class="infotable">
    <tr>
      <td colspan="2">
        <div style="opacity:.82" class="gamebox actionbox">
    #{Action_Forms}
        </div>
      </td>
    </tr>
    <tr>
      <td colspan="2">
        <div style="opacity:.82" class="gamebox infobox">
          <div style="beigeoverlay">
ENDTEXT

puts "<b><i>#{Dazed_Message}</i></b></br>" if Dazed_Message != ''
puts "<b>#{Action_Outcome}</b>" if Action_Outcome != ''
puts "<b>#{Tired_Message}</b>" if Tired_Message != ''
puts '<br><br>' if Action_Outcome != '' || Tired_Message != ''
puts Location_Info

puts <<ENDTEXT
        </div>
      </div>
    </td>
  </tr>
  <tr>
    <td width="25%">
      <div style="opacity:.82" class="gamebox invbox">
        <b>Weight: #{Encumberance}</b>
	<hr>
        <i>You are carrying:</i>
	#{Inventory}
        <hr>
        #{Drop}
      </div>
    </td>
    <td>
ENDTEXT

puts "<div class=\"gamebox msgbox\">#{Messages}</div>" if Messages != ''

puts <<~ENDTEXT
        <div class="gamebox">
         <b>Chat:</b>
          <div class="chatbox">
          #{html_chat_box(30)}
          <center><br>
           <a class="buttonlink" href="chat.cgi">Chat page</a>
          </center><br>
        </div>
         #{html_action_form('Chat', false, nil, 'game.cgi') { html_text_box(200) }}
       </div>
      </td>
    </tr>
  </table>
  </div>
  </body>
  </html>
ENDTEXT
