# -*- coding: utf-8 -*-

# ELTEN Mobile Code
# Copyright (C) Dawid Pieper
# This file and entire code are licensed under Open Public License
# For detailed information, refer to 'license.md' file

# Screen template to further usage
class ForumScreenTemplate < UI::Screen
  def on_load
    $screen = self

    @background = UI::View.new
    @background.flex = 1
    @background.margin = 5
    @background.background_color = :white
    self.view.add_child(@background)

    @list = UI::List.new
    @list.margin = [20, 20]
    @list.height = 420
    @background.add_child(@list)
  end
end

class ForumScreen < ForumScreenTemplate
  def on_show
    self.navigation.show_bar if self.navigation.bar_hidden?
    self.navigation.title = "Forum"
    @groups = []
    update_groups
    if $frmforumstask != nil
      $frmforumstask.stop
      $frmforumstask = nil
    end
    @maxid = 0
    task(false)
  end

  def on_load
    super

    @list.on :select do |opt, ind|
      if ind > 0
        group_screen = GroupScreen.new(@groups[ind - 1]["id"], @groups[ind - 1]["name"])
        self.navigation.push(group_screen)
      else
        threads_screen = ThreadsScreen.new("_followed", "Followed Threads")
        self.navigation.push(threads_screen)
      end
    end
    self.view.update_layout
  end

  def task(doUpdate = true)
    if self.navigation.screen == self
      Net.get(create_query("forum/maxid")) do |rsp|
        if rsp.body["code"] == 200 and @maxid < rsp.body["maxid"].to_i
          @maxid = rsp.body["maxid"].to_i
          if doUpdate
            update_groups
            play("forum_update")
          end
        end
      end
      $tmptask = Task.after(10) { task }
    end
  end

  def update_groups
    Net.get(create_query("forum/list", {"cat" => "groups"})) do |rsp|
      resp = rsp.body
      if resp["code"] != 200
        UI.alert({:title => "Error occurred", :message => resp["errmsg"]}) { }
      else
        @groups = resp["groups"]
        grp = []
        resp["groups"].each do |r|
          grp.push(r["name"] + "\r\nForums: " + r["forums"].to_s + "\r\nThreads: " + r["threads"].to_s + "\r\nPosts: " + r["posts"].to_s + "\r\nNew: " + (r["posts"].to_i - r["readposts"].to_i).to_s)
        end
        @list.data_source = ["Followed threads\r\nThreads: #{resp["foll_threads"].to_s}\r\nPosts: #{resp["foll_posts"].to_s}\r\nNew: #{(resp["foll_posts"].to_i - resp["foll_readposts"].to_i).to_s}"] + grp
      end
    end
  end
end

class GroupScreen < ForumScreenTemplate
  def initialize(id = 1, name = "")
    @id = id
    @name = name
    super
  end

  def on_show
    self.navigation.show_bar if self.navigation.bar_hidden?
    self.navigation.title = @name
    @forums = []
    update_forums
    if $frmthreadstask != nil
      $frmthreadstask.stop
      $frmthreadstask = nil
    end
    @maxid = 0
    task(false)
  end

  def on_load
    super

    @list.on :select do |opt, ind|
      threads_screen = ThreadsScreen.new(@forums[ind]["id"], @forums[ind]["name"])
      self.navigation.push(threads_screen)
    end
    self.view.update_layout
  end

  def task(doUpdate = true)
    if self.navigation.screen == self
      Net.get(create_query("forum/maxid")) do |rsp|
        if rsp.body["code"] == 200 and @maxid < rsp.body["maxid"].to_i
          @maxid = rsp.body["maxid"].to_i
          if doUpdate
            update_forums
            play("forum_update")
          end
        end
      end
      $frmforumstask = Task.after(10) { task }
    end
  end

  def update_forums
    Net.get(create_query("forum/list", {"cat" => "forums", "groupid" => @id})) do |rsp|
      resp = rsp.body
      if resp["code"] != 200
        UI.alert({:title => "Error occurred", :message => resp["errmsg"]}) { }
      else
        @forums = resp["forums"]
        frm = []
        resp["forums"].each do |r|
          frm.push(r["name"] + "\r\nThreads: " + r["threads"].to_s + "\r\nPosts: " + r["posts"].to_s + "\r\nNew: " + (r["posts"].to_i - r["readposts"].to_i).to_s)
        end
        @list.data_source = frm
      end
    end
  end
end

class ThreadsScreen < ForumScreenTemplate
  def initialize(id = 1, name = "")
    @id = id
    @name = name
    @type = 0
    super
  end

  def on_show
    self.navigation.show_bar if self.navigation.bar_hidden?
    self.navigation.title = @name
    @threads = []
    update_threads
    if $frmpoststask != nil
      $frmpoststask.stop
      $frmpoststask = nil
    end
    @maxid = 0
    task(false)
  end

  def on_load
    super

    @list.on :select do |opt, ind|
      posts_screen = PostsScreen.new(@threads[ind]["id"], @threads[ind]["name"])
      self.navigation.push(posts_screen)
    end

    @newbutton = UI::Button.new
    @newbutton.title = "New thread"
    @background.add_child(@newbutton)

    @newbutton.on :tap do
      newthread_screen = ThreadsNewScreen.new(@id, @type)
      self.navigation.push(newthread_screen)
    end

    self.view.update_layout
  end

  def task(doUpdate = true)
    if self.navigation.screen == self
      Net.get(create_query("forum/maxid")) do |rsp|
        if rsp.body["code"] == 200 and @maxid < rsp.body["maxid"].to_i
          @maxid = rsp.body["maxid"].to_i
          if doUpdate
            update_threads
            play("forum_update")
          end
        end
      end
      $frmthreadstask = Task.after(10) { task }
    end
  end

  def update_threads
    Net.get(create_query("forum/list", {"cat" => "threads", "forumid" => @id})) do |rsp|
      resp = rsp.body
      if resp["code"] != 200
        UI.alert({:title => "Error occurred", :message => resp["errmsg"]}) { }
      else
        @type = resp["forumtype"].to_i
        if (@type == 1 and (Recorder.permitted?) != false) or @type == -1
          @background.delete_child(@newbutton)
          self.view.update_layout
        end
        @threads = []
        thr = []
        acs = []
        resp["threads"].each do |r|
          @threads.push(r.clone)
          acs.push({})
          s = "Follow thread"
          s = "Unfollow thread" if r["followed"] == 1
          acs.last[s] = Proc.new { |opt, ind| chfollow(ind) }
          thr.push(((r["readposts"].to_i < r["posts"].to_i) ? "(NEW): " : "") + r["name"] + "\r\nPosts: " + r["posts"].to_s + "\r\nNew: " + (r["posts"].to_i - r["readposts"].to_i).to_s)
        end
        @list.data_source = thr
        @list.actions = acs
      end
    end
  end

  def chfollow(row)
    ind = row.row
    q = create_query("forum/follow", {"cat" => "thread", "threadid" => @threads[ind]["id"], "ac" => (@threads[ind]["followed"] == 1) ? "unfollow" : "follow"})
    Net.get(q) do |resp|
      rsp = resp.body
      if rsp["code"] == 200
        @threads[ind]["followed"] = (@threads[ind]["followed"] == 0) ? 1 : 0
        @list.actions[ind] = {(@threads[ind]["followed"] == 0) ? "Follow thread" : "Unfollow thread" => Proc.new { |opt, ind| chfollow(ind) }}
      else
        UI.alert(:title => "Error", :message => rsp["errmsg"]) { }
      end
    end
  end
end

class ThreadsNewScreen < UI::Screen
  def initialize(forum, type = l0)
    @forum = forum
    @type = type
  end

  def on_show
    self.navigation.hide_bar if !self.navigation.bar_hidden?
    self.navigation.title = "New Thread"
  end

  def on_load
    $screen = self

    @background = UI::View.new
    @background.flex = 1
    @background.margin = 5
    @background.background_color = :white
    self.view.add_child(@background)

    label = UI::Label.new
    label.text = "New thread"
    label.height = 50
    label.header = true
    @background.add_child(label)

    @title_field = UI::TextInput.new
    @title_field.height = 100
    @title_field.placeholder = "Title"
    @background.add_child(@title_field)

    @title_field.on :focus do
      @background.scale(1, 0.5)
    end

    @title_field.on :focus do
      @background.scale(0.3, 1)
    end

    if @type == 0
      post_view = UI::Text.new
      post_view.height = 250
      post_view.placeholder = "Post"
      @background.add_child(post_view)
      post_view.on(:focus) { @background.scale(1, 0.5) }
      post_view.on(:blur) { @background.scale(1, 1) }
    else
      @record = UI::Button.new
      @record.title = "Record post"
      @record.height = 100
      @background.add_child(@record)
      @record.on(:tap) { postrecbtn }
      $streamer = Player.new
    end

    cancel_button = UI::Button.new
    cancel_button.title = "Cancel"
    cancel_button.height = 50
    @background.add_child(cancel_button)

    cancel_button.on :tap do
      if (@type == 0 and post_view.text == "") or (@type == 1 and @recording != false)
        self.navigation.pop
      else
        UI.alert({:title => "Are you sure you want to cancel the creation of new thread?", :message => "All the typed text will be lost.", :cancel => "No", :default => "Yes"}) { |ind|
          self.navigation.pop if ind == :default
        }
      end
    end

    if @type == 0
      post_button = UI::Button.new
      post_button.title = "Create thread"
      post_button.height = 50
      @background.add_child(post_button)

      post_button.on :tap do
        if @title_field.text != "" and post_view.text != ""
          url = create_query("forum/edit", {"ac" => "add", "forum" => @forum.to_s, "threadid" => "new"})
          head = {"Content-Type" => "application/json"}
          body = {"threadname" => @title_field.text, "post" => post_view.text}
          Net.post(url, {:body => body, :headers => head}) do |rsp|
            if rsp.body["code"] != 200
              UI.alert({:title => "Unexpected error occurred while creating thread", :message => rsp.body["errmsg"]}) { }
            else
              self.navigation.pop
            end
          end
        end
      end
    end
  end

  def before_on_disappear
    recording_stop if @recording == true
    $streamer.stop if $streamer != nil
  end

  def postrecbtn
    if (Recorder.permitted?) == nil
      Recorder.request_permission(
        Proc.new { @background.delete_child(@record) },
        Proc.new { recording_start },
        Proc.new { }
      )
    elsif (Recorder.permitted?) == true
      if @recording == false or @recording == nil
        recording_start
      else
        recording_stop
      end
    end
  end

  def recording_start
    @background.delete_child(@play) if @play != nil
    @background.delete_child(@sendrec) if @sendrec != nil
    play("recording_start")
    @record.title = "Stop recording"
    @recording_file ||= ENV["TMPDIR"] + "/audiopost.m4a"
    File.delete(@recording_file) if FileTest.exists?(@recording_file)
    AudioConfig.category = AudioConfig::CategoryPlayAndRecord
    @recorder = Recorder.new(@recording_file)
    @recorder.start
    @recording = true
    self.view.update_layout
  end

  def recording_stop
    @recorder.stop
    AudioConfig.category = AudioConfig::CategoryAmbient
    @record.title = "Record again"
    @play = UI::Button.new
    @play.title = "Play recorded post"
    @play.height = 40
    @background.add_child(@play)
    @play.on(:tap) { $streamer.play(@recording_file) }
    @sendrec = UI::Button.new
    @sendrec.title = "Send"
    @sendrec.height = 60
    @background.add_child(@sendrec)
    @sendrec.on(:tap) { recording_send }
    play("recording_stop")
    @recording = false
    self.view.update_layout
  end

  def recording_send
    @record.title = "Sending..."
    @record.enabled = false
    @sendrec.enabled = false
    rece = File.get_data(@recording_file)

    url = create_query("forum/edit", {"ac" => "add", "threadid" => "new", "forum" => @forum.to_s, "src" => "-", "type" => "audio", "threadname" => @title_field.text})
    head = {"Content-Type" => "application/aac"}
    Net.post(url, {:body => rece, :headers => head}) do |rsp|
      if rsp.body["code"] != 200
        UI.alert({:title => "Error while sending your reply", :message => rsp.body["errmsg"]}) { }
      else
        self.navigation.pop
      end
    end
  end
end

class PostsScreen < ForumScreenTemplate
  def initialize(id = 1, name = "")
    @id = id
    @name = name
    super
  end

  def on_show
    self.navigation.show_bar if self.navigation.bar_hidden?
    self.navigation.title = @name
    @posts = []
    update_posts(true)
    @maxid ||= 0
    if $streamer != nil
      $streamer.stop
      $streamer = nil
    end
    task(false)
  end

  def on_load
    super

    @list.height = 250

    @list.on :select do |opt, ind|
      post = @posts[ind]
      if post["audio_url"] != nil and post["audio_url"] != ""
        if post["audio_url"] == @lasturl and $streamer.state != Player::StateNone and $streamer.position != $streamer.duration
          if $streamer.state == Player::StatePlaying
            $streamer.pause
          else
            $streamer.resume
          end
        else
          @lasturl = post["audio_url"]
          $streamer.play(@lasturl)
        end
      end
    end

    self.view.update_layout
  end

  def before_on_disappear
    if $streamer != nil
      $streamer.stop
      $streamer = nil
    end
    recording_stop if @recording == true
  end

  def task(doUpdate = true)
    if self.navigation.screen == self
      Net.get(create_query("forum/thread_maxid", {"thread" => @id.to_s})) do |rsp|
        if rsp.body["code"] == 200 and @maxid < rsp.body["maxid"].to_i and doUpdate
          update_posts
          play("forum_update")
        end
      end
      $frmpoststask = Task.after(5) { task }
    end
  end

  def update_posts(doScroll = false)
    Net.get(create_query("forum/posts", {"thread" => @id.to_s})) do |rsp|
      resp = rsp.body
      if resp["code"] != 200
        UI.alert({:title => "Error occurred", :message => resp["errmsg"]}) { }
      else
        @posts = resp["posts"]
        pst = []
        act = []
        cnt = 0
        resp["posts"].each do |r|
          act.push({"Show profile" => Proc.new { |act, row| self.navigation.push(ProfileScreen.new(@posts[row.row]["author"])) }})
          if $streamer == nil and r["audio_url"] != nil and r["audio_url"] != ""
            $streamer = Player.new
            if @record == nil and (Recorder.permitted?) != false
              @record = UI::Button.new
              @record.title = "Record Post"
              @record.margin = [5, 5]
              @record.height = 70
              @background.add_child(@record)
              @record.on(:tap) { record_btn }
            end
            self.view.update_layout
          end
          cnt += 1
          @maxid = r["id"].to_i if (@maxid || 0) < r["id"].to_i
          pst.push(((cnt <= resp["readposts"].to_i) ? "" : "(NEW): ") + r["author"] + "\r\n" + r["post"] + "\r\n" + r["date"])
        end
        @list.data_source = pst
        @list.actions = act
        if doScroll
          scroller = resp["readposts"].to_i - 1
          scroller = 0 if scroller < 0
          @list.scroll(scroller)
        end
      end
      if @reply == nil and $streamer == nil
        @reply = UI::Text.new
        @reply.editable = true
        @reply.margin = [0, 0]
        @reply.height = 100
        @reply.width = 400
        @reply.placeholder = "Your reply"
        @background.add_child(@reply)

        @reply.on(:focus) { @background.scale(1, 0.5) }

        @reply.on(:blur) { @background.scale(1, 1) }

        @button = UI::Button.new
        @button.title = "Post reply"
        @button.margin = [0, 0]
        @button.height = 80
        @background.add_child(@button)

        @button.on :tap do
          url = create_query("forum/edit", {"ac" => "add", "threadid" => @id.to_s})
          head = {"Content-Type" => "application/json"}
          Net.post(url, {:body => {"post" => @reply.text}, :headers => head}) do |rsp|
            if rsp.body["code"] != 200
              UI.alert({:title => "Error while sending your reply", :message => rsp.body["errmsg"]}) { }
            else
              update_posts
              @reply.text = ""
            end
          end
        end
        self.view.update_layout
      end
    end
  end

  def record_btn
    if (Recorder.permitted?) == nil
      Recorder.request_permission(
        Proc.new { @background.delete_child(@record) },
        Proc.new { recording_start },
        Proc.new { }
      )
    else (Recorder.permitted?) == true
      if @recording == false or @recording == nil
      recording_start
    else
      recording_stop
    end     end
  end

  def recording_start
    @background.delete_child(@play) if @play != nil
    @background.delete_child(@sendrec) if @sendrec != nil
    play("recording_start")
    @record.title = "Stop recording"
    @recording_file ||= ENV["TMPDIR"] + "/audiopost.m4a"
    File.delete(@recording_file) if FileTest.exists?(@recording_file)
    AudioConfig.category = AudioConfig::CategoryPlayAndRecord
    @recorder = Recorder.new(@recording_file)
    UI.alert(:title => "Error", :message => "Cannot initialize recorder") { } if !@recorder.start
    @recording = true
    self.view.update_layout
  end

  def recording_stop
    @recorder.stop
    AudioConfig.category = AudioConfig::CategoryAmbient
    @record.title = "Record again"
    @play = UI::Button.new
    @play.title = "Play recorded post"
    @play.height = 40
    @background.add_child(@play)
    @play.on(:tap) { $streamer.play(@recording_file) }
    @sendrec = UI::Button.new
    @sendrec.title = "Send"
    @sendrec.height = 60
    @background.add_child(@sendrec)
    @sendrec.on(:tap) { recording_send }
    play("recording_stop")
    @recording = false
    self.view.update_layout
  end

  def recording_send
    @record.title = "Sending..."
    @record.enabled = false
    @background.delete_child(@sendrec)
    rece = File.get_data(@recording_file)

    url = create_query("forum/edit", {"ac" => "add", "threadid" => @id.to_s, "src" => "-", "type" => "audio"})
    head = {"Content-Type" => "application/aac"}
    Net.post(url, {:body => rece, :headers => head}) do |rsp|
      @record.title = "Record post"
      @record.enabled = true
      if rsp.body["code"] != 200
        @background.add_child(@sendrec)
        UI.alert({:title => "Error while sending your reply", :message => rsp.body["errmsg"]}) { }
      else
        update_posts
        @background.delete_child(@sendrec)
        @background.delete_child(@play)
      end
    end
  end
end