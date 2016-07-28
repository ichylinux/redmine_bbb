require 'open-uri'
require 'rexml/document'

class Bbb
  def initialize(meetingID)
    @meetingID = meetingID
    @moderatorPW = Digest::SHA1.hexdigest("root" + meetingID)
    @attendeePW = Digest::SHA1.hexdigest("guest" + meetingID)
    @running = false
    @attendees = []

    @help_url = Setting.plugin_redmine_bbb['bbb_help']
    @back_url = Setting.plugin_redmine_bbb['bbb_url']
    @server = Setting.plugin_redmine_bbb['bbb_ip'].empty? ? Setting.plugin_redmine_bbb['bbb_server'] : Setting.plugin_redmine_bbb['bbb_ip']
    @popup = Setting.plugin_redmine_bbb['bbb_popup']
  end

  def self.salt
    Setting.plugin_redmine_bbb['bbb_salt']
  end

  def self.project_to_meetingID(project)
    meetingID = "00000" + project.id.to_s
    meetingID = meetingID[-5,5]
  end

  def create(meeting_name, back_url)
    @back_url = @back_url.empty? ? back_url : @back_url
    callApi(@server, "create","name=" + meeting_name + "&meetingID=" + @meetingID + "&attendeePW=" + @attendeePW +
                                         "&moderatorPW=" + @moderatorPW + "&logoutURL=" + @back_url + "&voiceBridge=" + @meetingID, true)
  end

  def join(password, fullName)
    return callApi(@server, "join", "meetingID=" + @meetingID + "&password="+ password + "&fullName=" + fullName, false)
  end

  def getinfo()
    isMeetingRunning = callApi(@server, 'isMeetingRunning', 'meetingID=' + @meetingID + '&password=' + @moderatorPW, true)
    return false if not isMeetingRunning

    doc = REXML::Document.new(isMeetingRunning)
    if doc.root.elements['returncode'].text == "SUCCESS"
      @running = doc.root.elements['running'].to_s.downcase == 'true'
      Rails.logger.info "meeting #{doc.root.elements['running']} => #{@running}"
    end

    if @running
      getMeetingInfo = callApi(@server, "getMeetingInfo","meetingID=" + @meetingID + "&password=" + @moderatorPW, true)
      return false if not getMeetingInfo

      doc = REXML::Document.new(getMeetingInfo)
      @attendees = []
      if doc.root.elements['returncode'].text == "SUCCESS"
        doc.root.elements['attendees'].each do |attendee|
          @attendees.push(attendee.elements['fullName'].text)
        end
      end
    end

    return true
  end

  def attendees
    @attendees
  end

  def moderatorPW
    @moderatorPW
  end

  def attendeePW
    @attendeePW
  end

  def help_url
    @help_url
  end

  def back_url
    @back_url
  end

  def running
    @running
  end

  def popup
    @popup
  end

  private

  def callApi(server, api, param, getcontent)
    tmp = api + param + self.class.salt
    checksum = Digest::SHA1.hexdigest(tmp)
    url = server + "/bigbluebutton/api/" + api + "?" + param + "&checksum=" + checksum

    if getcontent
      begin
        connection = open(url, {'Cache-Control' => 'no-cache', 'Pragma' => 'no-cache'})
        ret = connection.read
        #Rails.logger.info url + ' => ' + ret
        return ret

      rescue => e
        return false
      end
    else
      return url
    end
  end
end
