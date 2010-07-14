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

Have acpi periodically checked.
Update icon on charge
Display warning on <10%
Make it configurable

=end

require 'gtk2'

# Variables
##############

thread = nil
TIME_DELAY = 60

# Methods
##############

# Grabs the precentage from acpi output
def percentage
	perc = %x[acpi].split(", ")[1]
	return perc
end

# Creates the gtk object
def maketray
# Icon
###############
	trayicon = Gtk::StatusIcon.new
# Use a stock image, the disconnect one is pretty battery-like
	trayicon.stock = Gtk::Stock::DISCONNECT
# Tooltip
	trayicon.tooltip = "Battery: #{percentage}"

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
	thread = Thread.new(TIME_DELAY, trayicon) { |time, tray|
		while(true)
			sleep(time)	
			tray.tooltip = "Battery: #{percentage}"
		end
	}

# Main loop
###############
	Gtk.main
end

# Forking to background 
###############

process = Process.fork {
	maketray()
}

Process.detach(process)

puts "[1] #{process}"
