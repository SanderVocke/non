
###############################################################################
# Copyright (C) 2007-2008 Jonathan Moore Liles				      #
# 									      #
# This program is free software; you can redistribute it and/or modify it     #
# under the terms of the GNU General Public License as published by the	      #
# Free Software Foundation; either version 2 of the License, or (at your      #
# option) any later version.						      #
# 									      #
# This program is distributed in the hope that it will be useful, but WITHOUT #
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or	      #
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for   #
# more details.								      #
# 									      #
# You should have received a copy of the GNU General Public License along     #
# with This program; see the file COPYING.  If not,write to the Free Software #
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.  #
###############################################################################

# Makefile for the Non Sequencer.

#
# Do not edit this file; run `make config` instead.
#

VERSION := 1.9.2

all: .config non-sequencer

.config: configure
	@ ./configure

config:
	@ ./configure

-include .config

SYSTEM_PATH=$(prefix)/share/non-sequencer/
DOCUMENT_PATH=$(prefix)/share/doc/non-sequencer/

# a bit of a hack to make sure this runs before any rules
ifneq ($(CALCULATING),yes)
TOTAL := $(shell $(MAKE) CALCULATING=yes -n 2>/dev/null | sed -n 's/^.*Compiling: \([^"]\+\)"/\1/p' > .files )
endif

ifeq ($(USE_DEBUG),yes)
	CXXFLAGS := -pipe -ggdb -Wall -Wextra -Wnon-virtual-dtor -Wno-missing-field-initializers -O0 -fno-rtti -fno-exceptions
else
	CXXFLAGS := -pipe -O2 -fno-rtti -fno-exceptions -DNDEBUG
endif

CFLAGS+=-DINSTALL_PREFIX=\"$(prefix)\" \
	-DSYSTEM_PATH=\"$(SYSTEM_PATH)\" \
	-DDOCUMENT_PATH=\"$(DOCUMENT_PATH)\"

CXXFLAGS:=$(CFLAGS) $(CXXFLAGS) $(FLTK_CFLAGS) $(SIGCPP_CFLAGS) $(LASH_CFLAGS)

LIBS:=$(FLTK_LIBS) $(JACK_LIBS) $(LASH_LIBS) $(SIGCPP_LIBS)

ifeq ($(JACK_MIDI_PROTO_API),yes)
	CXXFLAGS+=-DJACK_MIDI_PROTO_API
endif

# uncomment this line to print each playback event to the console (not RT safe)
# CXXFLAGS+= -DDEBUG_EVENTS

SRCS:=$(wildcard src/*.C src/gui/*.fl src/gui/*.C)

SRCS:=$(SRCS:.fl=.C)
SRCS:=$(sort $(SRCS))
OBJS:=$(SRCS:.C=.o)

.PHONEY: all clean install dist valgrind config

clean:
	rm -f non-sequencer .deps $(OBJS)
	@ echo "$(DONE)"

valgrind:
	valgrind ./non-sequencer

include scripts/colors

ifneq ($(CALCULATING),yes)
	COMPILING="$(BOLD)$(BLACK)[$(SGR0)$(CYAN)`scripts/percent-complete .files "$<"`$(SGR0)$(BOLD)$(BLACK)]$(SGR0) Compiling: $(BOLD)$(YELLOW)$<$(SGR0)"
else
	COMPILING="Compiling: $<"
endif

.C.o:
	@ echo $(COMPILING)
	@ $(CXX) $(CXXFLAGS) -c $< -o $@

%.C : %.fl
	@ cd $(dir $<) && fluid -c $(notdir $<)

$(OBJS): .config

DONE:=$(BOLD)$(GREEN)done$(SGR0)

non-sequencer: $(OBJS)
	@ echo -n "Linking..."
	@ rm -f $@
	@ scripts/build_id .version.c $(VERSION)
	@ $(CXX) -c .version.c
	@ $(CXX) $(CXXFLAGS) $(LIBS) $(OBJS) .version.o -o $@ || echo "$(BOLD)$(RED)Error!$(SGR0)"
	@ if test -x $@; then echo "$(DONE)"; test -x "$(prefix)/bin/$@" || echo "You must now run 'make install' (as the appropriate user) to install the executable, documentation and other support files in order for the program to function properly."; fi

install: all
	@ echo -n "Installing..."
	@ install non-sequencer $(prefix)/bin
	@ mkdir -p "$(SYSTEM_PATH)"
	@ cp -r instruments "$(SYSTEM_PATH)"
	@ mkdir -p "$(DOCUMENT_PATH)"
	@ cp doc/*.html doc/*.png "$(DOCUMENT_PATH)"
	@ echo "$(DONE)"
ifneq ($(USE_DEBUG),yes)
	@ echo -n "Stripping..."
	@ strip $(prefix)/bin/non-sequencer
	@ echo "$(DONE)"
endif

dist:
	git archive --prefix=non-sequencer-$(VERSION)/ v$(VERSION) | bzip2 > non-sequencer-$(VERSION).tar.bz2

TAGS: $(SRCS)
	etags $(SRCS)

.deps: .config $(SRCS)
	@ echo -n Calculating dependencies...
	@ makedepend -f- -- $(CXXFLAGS) $(INCLUDES) -- $(SRCS) > .deps 2>/dev/null && echo $(DONE)

-include .deps
