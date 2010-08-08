#!/usr/bin/env ruby
# encoding: UTF-8

=begin

Copyright 2010 Carl Ellis

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

Battery monitor I hope. Should show the percentage of battery in the tooltip.

TODO:

Update icon on charge
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

	attr_accessor :id, :dc, :percent, :time

	# Default constructor
	def initialize
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
			@dc = (dcraw == "Charging") ? Battery::CHARGING : Battery::DISCHARGING

			# Percent
			@percent = output[1]

			# Time Remaining
			@time = (output[2].nil?)? "" : output[2].strip
		rescue Exception => e
			#puts e
		end
	end

	# String output
	def to_s
		return "Battery - id: #{@id}, dc:#{@dc}, percent:#{@percent}, time:#{@time}"
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
