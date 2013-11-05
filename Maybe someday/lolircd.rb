#!/usr/bin/env ruby
require 'pp'
require 'socket'
require 'set'

require '/home/grawity/code/lib/ruby/irc.rb'

$conf = {
	password: "jilles",
	sid: "123",
	name: "ratbox.rain",
	description: "lolz",
}

def match(mask, str)
	File.fnmatch(mask, str, File::FNM_DOTMATCH)
end

class Peer
	attr_accessor :fd, :state, :capab

	def initialize(fd)
		@fd		= fd
		@state	= nil
		@capab	= Set[]
	end

	def send(*args)
		@fd.puts IRC.join(args)
	end

	def sendas(prefix, *args)
		if prefix.nil?
			if @capab.include? :sid
				prefix = $conf[:sid]
			else
				prefix = $conf[:name]
			end
		end
		send(":#{prefix}", *args)
	end

	def recv
		IRC.parse(@fd.gets)
	end
end

class Server < Peer
	attr_accessor :sid, :name, :hops, :desc, :nexthop

	def initialize(fd, sid=nil, name=nil, hops=nil, desc=nil, nexthop=nil)
		super(fd)
		@sid		= sid
		@name		= name
		@hops		= hops
		@desc		= desc
		@nexthop	= nexthop
		@links		= Set[]
	end
end

class User < Peer
	attr_accessor :uid, :nick, :hops, :ts, :mode, :username, :host, :gecos, :channels

	def initialize(fd, uid=nil, nick=nil, hops=nil, ts=nil, mode=nil, username=nil, host=nil, gecos=nil)
		super(fd)
		@uid		= uid
		@nick		= nick
		@hops		= hops
		@ts			= ts
		@mode		= mode
		@username	= username
		@host		= host
		@gecos		= gecos
		@channels	= Set[]
	end

	def sid
		@uid[0..2]
	end

	def nuh
		@nick + "!" + @username + "@" + @host
	end

	def name
		@nick + "!" + @username + "@" + @host
	end
end

class Channel
	attr_accessor :name, :ts
	attr_accessor :topic, :topic_setter
	attr_accessor :modes, :key, :limit
	attr_accessor :members, :ops, :voices

	def initialize(name, ts)
		@name		= name
		@ts			= ts

		@topic			= nil
		@topic_setter	= nil

		@modes		= Set[]
		@key		= nil
		@limit		= nil

		@members	= Set[]
		@ops		= Set[]
		@voices		= Set[]
	end

	def update_modes(modes, setter)
		modes, *args = modes.join(" ").split
		add = true
		i = 0
		modes.each_char do |c|
			case c
			when "+"
				add = true
			when "-"
				add = false
			when "k"
				if add
					@key = args[i]
				else
					@key = nil
				end
				i += 1
			when "l"
				if add
					@limit = args[i].to_i
					i += 1
				else
					@limit = nil
				end
			when "m", "n", "i", "s", "t"
				if add
					@modes.add c
				else
					@modes.delete c
				end
			else
				# TODO: client.send
			end
		end
	end
end

class State
	def initialize
		@conns = Hash[]
		@nicks = Hash[]
		@uids = Hash[]
		@servers = Hash[]
		@sids = Hash[]
		@sockets = Set[]
		@channels = Hash[]
	end

	def init
		fd = Addrinfo.tcp("::1", 6667).listen
		@sockets << fd

		fd = Addrinfo.tcp("::1", 26005).connect
		server = Server.new(fd)
		server.send("PASS", $conf[:password], "TS", "6", $conf[:sid])
		server.send("CAPAB", "ENCAP TB")
		server.send("SERVER", $conf[:name], "0", $conf[:description])
		@conns[fd] = server
		@sockets << fd
	end

	def run
		loop do
			rd, _, _ = IO.select(@sockets.to_a)
			rd.each do |fd|
				handle_input(fd)
			end
		end
	end

	def find_servers_by_mask(mask)
		@servers.select{|name, server| match(mask, name)}
	end

	def find_nexthop_for_server(name)
		server = @servers[name]
		while server.nexthop
			server = @sids[server.nexthop]
		end

		return server
	end

	def find_entity(name)
		@uids[name] || @nicks[name] || @sids[name] || @servers[name]
	end

	def send_servers(except, *argv)
		@servers.each do |_, server|
			if server.fd and server != except
				server.send(*argv)
			end
		end
	end

	def sendas_servers(except, *argv)
		@servers.each do |_, server|
			if server.fd and server != except
				server.sendas(*argv)
			end
		end
	end

	def handle_user_command(conn, source, cmd, argv)
		pp source: source, cmd: cmd, argv: argv
	end

	def handle_server_command(conn, source, cmd, argv)
		pp source: source, cmd: cmd, argv: argv

		case cmd
		when "CAPAB" # TODO
			puts "\e[33mUnknown command #{cmd}!\e[m"
			caps = argv.join(" ").split.map(&:to_sym)
			pp source: source, capab: caps
			conn.capab += caps

		when "ENCAP"
			mask, *rest = argv
			pp source: source, encap: {mask: mask, rest: rest}

			if match(mask, $conf[:name])
				ecmd, *eargv = rest
				ecmd.upcase!
				handle_encap(conn, source, ecmd, eargv)
			end

			servers = find_servers_by_mask(mask)
			nexthops = servers.map{|name, _| find_nexthop_for_server(name)}.uniq
			nexthops.each do |server|
				if server != conn
					server.sendas(source, "ENCAP", mask, *rest)
				end
			end

		when "JOIN"
			ts, cname, modes = argv
			ts = ts.to_i

			chan = @channels[cname]
			chan.members.add(source)
			user = @uids[source]
			user.channels.add(cname)
			puts "channel member added: #{source} to #{cname}"

			sendas_servers(source, cmd, *argv)

		when "PART"
			cname, reason = argv

			if chan = @channels[cname]
				if chan.members.delete? source
					chan.ops.delete(source)
					chan.voices.delete(source)
					if user = @uids[source]
						user.channels.delete(cname)
					end
					puts "channel member removed: #{source} from #{cname}"
				end

				if chan.members.empty?
					@channels.delete cname
					puts "channel destroyed: #{cname}"
				end
			end

			sendas_servers(source, cmd, *argv)

		when "PASS"
			pass, proto, proto2, sid = argv
			conn.sid = sid
			@sids[sid] = conn

		when "PING"
			origin, dest = *argv
			if dest.nil? or dest == $conf[:sid]
				conn.sendas(nil, "PONG", $conf[:name], source)
			elsif server = find_nexthop_for_server(dest)
				server.sendas(source, cmd, *argv)
			end

		when "SERVER"
			name, hops, desc = argv
			if source
				server = Server.new(nil, nil, name, hops.to_i, desc, source)
				@servers[name] = server
				# forward
				sendas_servers(source, cmd, *argv)
			else
				server = conn
				server.name = name
				server.hops = hops.to_i
				server.desc = desc
				@servers[name] = server
				# forward
				sendas_servers(name, cmd, *argv)
			end

		when "SID"
			name, hops, sid, desc = argv

			server = Server.new(nil, sid, name, hops.to_i, desc, source)
			@servers[name] = server
			@sids[sid] = server
			puts "New server #{server.name}/#{server.sid} via #{server.nexthop}"

			sendas_servers(source, cmd, *argv)

		when "SJOIN"
			ts, name, *modes, users = argv

			chan = @channels[name] ||= Channel.new(name, modes)
			users.split.each do |user|
				if uname =~ /^([@+]*)/
					prefix = $1
					uname = $'
				end
				chan.members << uname
				chan.ops << uname		if prefix =~ /@/
				chan.voices << uname	if prefix =~ /\+/
				if user = @uids[uname]
					user.channels << name
				end
			end

			sendas_servers(source, cmd, *argv)

		when "TB"
			name, ts, setter, topic = argv

			if chan = @channels[name]
				ts = ts.to_i

				if topic
					chan.topic = topic
					chan.topic_setter = setter
				else
					chan_topic = setter
					chan.topic_setter = find_entity(source).name
				end
			end

			sendas_servers(source, cmd, *argv)
		when "TMODE"
			ts, name, *modes = argv
			chan = @channels[name]
			chan.update_modes(modes, source)
			# forward
			sendas_servers(source, cmd, *argv)
		when "TOPIC"
			name, topic = argv
			chan = @channels[name]
			chan.topic = topic
			chan.topic_setter = @uids[source].nuh
			# forward
			sendas_servers(source, cmd, *argv)
		when "UID"
			nick, hopc, nick_ts, umodes, username, host, raddr, uid, gecos = argv
			user = User.new(nil, uid, nick, hopc.to_i, nick_ts.to_i, umodes, username,
							host, gecos)
			@nicks[nick] = user
			@uids[uid] = user
			puts "New user #{user.nick}/#{user.uid} from server #{user.sid}"
			# forward
			sendas_servers(source, cmd, *argv)
		else
			puts "\e[33mUnknown command #{cmd}!\e[m"
		end
	end

	def handle_encap(conn, source, cmd, argv)
		case cmd
		when "GCAP"
			caps = argv.join(" ").split.map(&:to_sym)
			server = @sids[source]
			server.capab += caps
		else
			puts "\e[33mUnknown encap #{cmd}!\e[m"
			pp source: source, cmd: cmd, argv: argv
		end
	end

	def handle_input(fd)
		conn = @conns[fd]

		while line = fd.gets
			line = IRC.parse(line)
			line.argv[0].upcase!
			source = line.prefix
			cmd, *argv = line.argv
			handle_server_command(conn, source, cmd, argv)
		end
	end
end

$self = State.new
$self.init
$self.run

# vim: ts=4:sw=4
