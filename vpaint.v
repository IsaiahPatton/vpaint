module main

import stbi
import os
import gg
import iui as ui
import gx

// Our storage
struct KA {
pub mut:
	window    &ui.Window = 0
	width     int
	height    int
	file      stbi.Image
	ggim      int
	strr      int
	iid       int
	draw_size int = 1
	color     gx.Color
	off_color gx.Color = gx.gray
	brush     Brush    = PencilBrush{}
	lx        int
	ly        int
	cl        int
}

[console]
fn main() {
	mut path := os.resource_abs_path('test.png')
	mut win := ui.window(ui.get_system_theme(), 'vPaint', 800, 550)

	background := gx.rgb(210, 220, 240)
	win.id_map['background'] = &background

	if os.args.len > 1 {
		// Open file
		path = os.args[1]
		win.extra_map['save_path'] = path
	}

	if !os.exists(path) {
		mut blank_png := $embed_file('test.png')
		os.write_file_array(path, blank_png.to_bytes()) or {}
	}

	mut png_file := read(path) or { panic(err) }
	win.bar = ui.menubar(win, win.theme)

	mut storage := &KA{
		window: win
		file: png_file
		width: png_file.width
		height: png_file.height
		ggim: -1
	}
	win.id_map['pixels'] = storage

	testt := 430 / png_file.height
	if testt > 0 {
		win.extra_map['zoom'] = testt.str()
	} else {
		win.extra_map['zoom'] = '1'
	}

	file_menu := ui.menu_item(
		text: 'File'
		children: [
			ui.menu_item(
				text: 'Save...'
				click_event_fn: save_as_click
			),
			ui.menu_item(
				text: 'Save As...'
				click_event_fn: save_as_click
			),
		]
	)

	win.bar.add_child(file_menu)

	help_menu := ui.menu_item(
		text: 'Help'
		children: [
			ui.menu_item(
				text: 'About vPaint'
				click_event_fn: about_click
			),
			ui.menu_item(
				text: 'About iUI'
			),
		]
	)

	make_zoom_menu(mut win)
	make_brush_menu(mut win)
	make_draw_size_menu(mut win)

	mut theme_menu := ui.menuitem('Theme')
	mut themes := ui.get_all_themes()
	for theme2 in themes {
		mut item := ui.menuitem(theme2.name)
		item.set_click(theme_click)
		theme_menu.add_child(item)
	}

	win.bar.add_child(theme_menu)
	win.bar.add_child(help_menu)

	make_toolbar(mut win)

	mut lbl := ui.label(win, '')
	lbl.set_pos(10, 40 + 40)
	lbl.pack()
	lbl.set_id(mut win, 'canvas')
	lbl.draw_event_fn = fn (mut win ui.Window, com &ui.Component) {
		draw_image(mut win, com)
	}

	lbl.scroll_change_event = fn [win] (lbl &ui.Component, delta int, dir int) {
		mut slide := &ui.Slider(win.get_from_id('y_slide'))
		zoom := win.extra_map['zoom']
		if delta < 0 {
			slide.scroll_i -= zoom.int()
		} else {
			slide.scroll_i += zoom.int()
		}
		if slide.scroll_i < 0 {
			slide.scroll_i = 0
		}
	}

	win.add_child(lbl)
	make_status_bar(mut win)
	make_sliders(mut win)

	win.gg.run()
}

fn make_sliders(mut win ui.Window) {
	mut y_slide := ui.slider(win, 0, 0, .vert)
	y_slide.set_bounds(0, 70, 18, 100)
	y_slide.set_id(mut win, 'y_slide')
	y_slide.draw_event_fn = fn (mut win ui.Window, comm &ui.Component) {
		mut com := *comm
		if mut com is ui.Slider {
			mut canvas := &ui.Label(win.get_from_id('canvas'))
			com.max = canvas.height

			size := gg.window_size()
			com.hide = canvas.height < (size.height - 50)

			com.x = size.width - com.width
			com.height = size.height - 30 - 65
		}
	}
	y_slide.z_index = 15
	win.add_child(y_slide)

	mut x_slide := ui.slider(win, 0, 0, .hor)
	x_slide.set_bounds(0, 26, 0, 18)
	x_slide.set_id(mut win, 'x_slide')
	x_slide.draw_event_fn = fn (mut win ui.Window, comm &ui.Component) {
		mut com := *comm
		if mut com is ui.Slider {
			mut canvas := &ui.Label(win.get_from_id('canvas'))
			com.max = canvas.width

			size := gg.window_size()
			com.hide = canvas.width < (size.width - 50)

			com.y = size.height - com.height - 25
			com.width = size.width - 18
		}
	}
	x_slide.z_index = 15
	win.add_child(x_slide)
}

fn about_click(mut win ui.Window, com ui.MenuItem) {
	mut about := ui.modal(win, 'About vPaint')
	about.in_height = 250
	about.in_width = 350

	mut title := ui.label(win, 'vPaint')
	title.set_pos(12, 8)
	title.set_config(16, false, true)
	title.pack()
	about.add_child(title)

	mut lbl := ui.label(win,
		'Simple Image Viewer & Editor written\nin the V Programming Language.' +
		'\n\nThis program is free software licensed under\nthe GNU General Public License v2.\n\nIcons by Icons8')
	lbl.set_pos(12, 70)
	about.add_child(lbl)

	mut copy := ui.label(win, 'Copyright ?? 2021-2022 Isaiah.')
	copy.set_pos(12, 195)
	copy.set_config(12, true, false)
	about.add_child(copy)

	win.add_child(about)
}

fn save_as_click(mut win ui.Window, com ui.MenuItem) {
	mut modal := ui.page(win, 'Save As')
	mut vbox := ui.vbox(win)
	vbox.set_pos(16, 16)

	mut l1 := ui.label(win, 'File path:')
	l1.pack()
	l1.set_pos(30, 16)
	vbox.add_child(l1)

	mut path := ui.textfield(win, '')
	path.set_id(mut win, 'save-as-path')
	path.set_bounds(32, 2, 300, 25)

	if 'save_path' in win.extra_map {
		path.text = win.extra_map['save_path']
	}
	vbox.add_child(path)

	mut hbox := ui.hbox(win)
	hbox.set_pos(30, 16)

	mut l2 := ui.label(win, 'Save as type: ')
	l2.pack()
	l2.set_pos(0, 6)
	hbox.add_child(l2)

	mut typeb := ui.selector(win, 'PNG (*.png)')
	typeb.items << 'PNG (*.png)'
	typeb.items << 'JPEG (*.jpg)'
	typeb.set_bounds(8, 0, 200, 25)
	hbox.add_child(typeb)

	mut save := ui.button(win, 'Save')
	save.set_bounds(30, 32, 96, 44)
	save.set_click(fn [path, typeb] (mut win ui.Window, btn ui.Button) {
		canvas := &KA(win.id_map['pixels'])
		file := canvas.file

		win.extra_map['save_path'] = path.text

		if typeb.text.contains('.jpg') {
			write_jpg(file, path.text)
		} else {
			write_img(file, path.text)
		}

		win.components = win.components.filter(mut it !is ui.Page)
	})
	hbox.pack()
	hbox.z_index = 1
	vbox.add_child(hbox)
	vbox.add_child(save)

	modal.add_child(vbox)
	win.add_child(modal)
}
