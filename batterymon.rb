#!/usr/bin/env ruby
# encoding: UTF-8

=begin

Copyright 2012 Carl Ellis

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
=end

=begin

Battery monitor. Shows the percentage of battery charge in the tooltip.

TODO:

Display warning on <10%
Make it configurable

=end

require 'gtk2'

# Classes
##############

# Describes a battery class
class Battery

	CHARGING = 1
	DISCHARGING = 0

	attr_accessor :id, :dc, :percent, :time, :history, :av_charge, :prev_p, :lpercent, :i

	# Default constructor
	def initialize
		@history = []
		@av_charge = 0
		@prev_p = nil
		update()
	end

	# Grabs the battery status from acpi output
	def update
		
		begin

			output = %x[acpi].split(", ")

			# Battery id
			fsec = output[0]
			@id = fsec.match(/^.*\s([0-9]+).*$/)[1]

			# Battery state
			dcraw = fsec.match(/^.*:\s(.*)$/)[1]
			# If full sets to charging state for the correct icon
			@dc = (dcraw == "Charging") ? Battery::CHARGING : (output[2].nil?)? Battery::CHARGING : Battery::DISCHARGING

			# Percent
			@lpercent = (@percent.nil?) ? output[1] : @percent
			@percent = output[1]

			# Time Remaining
			@time = (output[2].nil?)? "Full" : output[2].strip
			@time = (@time.include?("will never fully charge")) ? "Calculating..." : @time

			# If chargin add to history and do own charging estimate as ACPI isnt great at it
			if (@dc == Battery::CHARGING)

				# Wait until a charge state change has been completely observed
				if (@prev_p.nil?)
					# If a state change is observed, start the counting
					if (@lpercent.to_i < @percent.to_i)
						@prev_p = @percent
						@i = 0
					end
				else
					# Observed state change while counting, record charge rate
					if(@prev_p.to_i < @percent.to_i)
						#puts "Prev:#{@prev_p} Current:#{@percent}, eq:#{@prev_p < @percent}"
						@prev_p = @percent
						@history << @i * TIME_DELAY # will be a maximum size of 99
						@i = 0
					else
						@i += 1
					end
				end

				# Get the average charge per second
				@av_charge = 0
				@history.collect {|c| @av_charge += c}
				@av_charge /= @history.length.to_f

				# Make sure there is a measurable change
				if !@av_charge.nan?
					@av_charge = av_charge

					# Calculate time to full chage (ROUGH)
					c_togo = 100-@percent.to_i.to_f
					secs = c_togo*@av_charge
					@time = to_time(secs - (@i*TIME_DELAY))
				end
			else
				@history = []
				@prev_p = nil
			end

		rescue Exception => e
			#puts e
		end
	end

	# Converts seconds into time
	def to_time(secs)
		hours = (secs/60/60).to_i
		secs -= hours*60*60
		mins = (secs/60).to_i
		secs -= mins*60
		secs = secs.to_i
		return "#{hours.to_s}:#{mins.to_s.rjust(2,"0")}:#{secs.to_s.rjust(2,"0")}"
	end

	# String output
	def to_s
		return "Battery - id: #{@id}, dc:#{@dc}, percent:#{@percent}, time:#{@time} av_c:#{@av_charge} #{@history.to_s}"
	end

end

# Variables
##############

thread = nil
TIME_DELAY = 10
battery = Battery.new

# Icon
###############
trayicon = Gtk::StatusIcon.new
# Use a stock image, the disconnect one is pretty battery-like
trayicon.stock = Gtk::Stock::DISCONNECT
# Tooltip
trayicon.tooltip = "Battery: #{battery.percent}"

# Menu
###############
# Quit icon
quit = Gtk::ImageMenuItem.new(Gtk::Stock::QUIT)
quit.signal_connect('activate'){
	thread.kill
	Gtk.main_quit
}
# Build
menu = Gtk::Menu.new
menu.append(quit)
menu.show_all

# Events and signals
###############
trayicon.signal_connect('popup-menu'){  |tray, button, time|
	menu.popup(nil, nil, button, time)
}

# Thread for updating tooltip
###############
thread = Thread.new(TIME_DELAY, trayicon, battery) { |time, tray, bat|
	while(true)
		# Only update every given time chunk
		sleep(time)
		bat.update()

		# Change icon accordingly
    tray.stock = (bat.dc == Battery::CHARGING) ? Gtk::Stock::CONNECT : Gtk::Stock::DISCONNECT
		tray.tooltip = "Battery #{bat.id}: #{bat.percent}\n#{bat.time}"
	end
}

# Main loop
###############
Gtk.main
