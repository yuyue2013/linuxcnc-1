#!/usr/bin/env python
"""Usage:
    python teach.py outputfile nmlfile
If outputfile is not specified, writes to standard output.

You must ". scripts/emc-environment" before running this script, if you use
run-in-place.
"""
#    Copyright 2007 Jeff Epler <jepler@unpythonic.net>
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

import sys, os
BASE = os.environ['EMC2_HOME']
sys.path.insert(0, os.path.join(BASE, "lib", "python"))

import gettext;
gettext.install("emc2", localedir=os.path.join(BASE, "share", "locale"), unicode=True)

import emc
import Tkinter 
import tkMessageBox
from Tkinter import *
from scipy import mat
from scipy import linalg


linenumber = 1;

if len(sys.argv) > 2:
    emc.nmlfile = sys.argv[1]

#if len(sys.argv) > 1:
#    outfile = sys.argv[1]
#    sys.stdout = open(outfile, 'w')

#else:
#    sys.stdout = open('../Teached.ngc', 'w')

#
#  Output relative config ngc file header for SRX611
#

file_header = "\
(Generated by Arais Robot Technology: EMC2 teach-in 2010)\n\
\n\
G21 G90 G54\n\
#1000 = 0.0000  ( X Shift )\n\
#1001 = 0.0000  ( Y Shift )\n\
#1002 = 0.0000  ( Z Shift )\n\
#1003 = 0.0000  ( A Shift )\n\
\n\n\
"
feed_rate_string = ""

output_string = "F#3000 \n\
(Learned Path)\n\
"

s = emc.stat()
   
def save_quit():
    if len(sys.argv) > 1:
        outfile = sys.argv[1]
    if tkMessageBox.askokcancel( \
            "Save and Quit", \
            "Save to %s and quit now?" % outfile):
        outfile = sys.argv[1]
        f = open(outfile, 'w')
        text.insert(END, "M2")
        f.write(text.get(1.0, END))
        f.close()
        app.destroy()
    return

def get_textbox_data():
    global file_header
    global feed_rate_string
    global output_string
    file_header = text.get(0.0, 9.0)
#    print file_header
    feed_rate_string = text.get(9.0,"13.0")
    output_string = text.get(13.0,END)
    entry1.delete(0, END)
    entry1.insert(0, text.get("9.8","9.end"))
    entry2.delete(0, END)
    entry2.insert(0, text.get("10.8","10.end"))
    entry3.delete(0, END)
    entry3.insert(0, text.get("11.8","11.end"))
    button4.config(state=DISABLED)
    return

def textbox_changed(event):
# disable apply button
    button4.config(state=NORMAL)
    return

def feedrate_press(event):
    update_feed_string()
    return

def update_textbox():
    global file_header
    global feed_rate_string
    global output_string
    text.delete(0.0,END)
    text.insert(INSERT, file_header)
    text.insert(INSERT, feed_rate_string)
    text.insert(INSERT, output_string)
    return

def update_feed_string():
    global file_header
    global feed_rate_string
    global output_string
    feed_rate_string = "#3000 = " + entry1.get() +"\n"
    feed_rate_string = feed_rate_string+"#3001 = " + entry2.get() +"\n"
    feed_rate_string = feed_rate_string+"#3002 = " + entry3.get() +"\n\n"
    update_textbox()
    return

def get_cart():
    s.poll()
    position = " ".join(["%-8.4f"] * s.axes)
    return position % s.position[:s.axes]
    
def get_joint():
    s.poll()
    position = " ".join(["%-8.4f"] * s.axes)
    return position % s.joint_actual_position[:s.axes]

points = {}
def log():
    global output_string
    global total_pts
    global cur_pt
    global msg
    # p = get_cart()
    # p = "X:"+p.split(' ')[0]+" Y:"+p.split(' ')[1]+" Z:"+p.split(' ')[2]+" A:"+p.split(' ')[3]
    # label1.configure(text='%s' % p)
    # print "G1X["+p.split(' ')[0]+"+#1000]Y["+p.split(' ')[1]+ "+#1001]Z[" + p.split(' ')[2] +"+#1002]A["+ p.split(' ')[3]+"+#1003]"
    s.poll()
    mode=v.get()
    if ((mode == "G0") or (mode == "G1")):
        output_string = output_string + mode + \
                        " X%-8.4f Y%-8.4f Z%-8.4f A%-8.4f\n" % s.position[:s.axes]
        update_textbox()
        points_init()
    elif ((mode == "G2") or (mode == "G3")):
        points[cur_pt] = s.position[:s.axes]
        cur_pt += 1
        tmp = "%s: points(%d/%d)" % (mode, cur_pt, total_pts)
        for i in range (0, cur_pt):
            position = " ".join(["%-8.4f"] * s.axes)
            position = position % points[i][:s.axes]
            tmp = tmp + "\n%s" % position 
        msg.set("%s" % tmp)
        if (cur_pt == total_pts):
            A = mat([[points[0][0], points[0][1], 1], \
                     [points[1][0], points[1][1], 1], \
                     [points[2][0], points[2][1], 1]])
            b = mat([[-points[0][0]**2 - points[0][1]**2], \
                     [-points[1][0]**2 - points[1][1]**2], \
                     [-points[2][0]**2 - points[2][1]**2]])
            print A
            print b
            d, e, f = linalg.solve(A,b)
            print "center: (%f, %f)" % (-d/2, -e/2)
            # calc I and J for XY plane
            i = -d/2 - points[0][0]
            j = -e/2 - points[0][1]
            output_string = output_string + mode + \
                            " X%-8.4f Y%-8.4f Z%-8.4f A%-8.4f" % points[2] + \
                            " I%-8.4f J%-8.4f\n" % (i, j)
            update_textbox()
            points_init()

def ins_feed_3000():
    global output_string
    output_string = output_string +"F#3000\n"
    update_textbox()
    button4.config(state=DISABLED)
    return    
    
def ins_feed_3001():
    global output_string
    output_string = output_string +"F#3001\n"
    update_textbox()
    button4.config(state=DISABLED)
    return    
  
def ins_feed_3002():
    global output_string
    output_string = output_string +"F#3002\n"
    update_textbox()
    button4.config(state=DISABLED)
    return      
    
def show():
    s.poll()
    #if world.get():
    p = get_cart()
    # p = "X:["+p.split(' ')[0]+"] Y:["+p.split(' ')[1]+"] Z:["+p.split(' ')[2]+"] A:["+p.split(' ')[3]+"]"
    #else:
    #    p = get_joint()
#        p = "J0:["+p.split(' ')[0]+"] J1:["+p.split(' ')[1]+"] J2:["+p.split(' ')[2]+"] J3:["+p.split(' ')[3]+"]"
    label2.configure(text='%s' % p)
#    labXval.configure(text='%s' % p.split(' ')[0])
#    labYval.configure(text='%s' % p.split(' ')[1])
#    labZval.configure(text='%s' % p.split(' ')[2])
#    labAval.configure(text='%s' % p.split(' ')[3])
    app.after(100, show)

det = 0
def destory_bind(x):
    global det
    global file_header
    global feed_rate_string
    global output_string
    if det == 0:   
        output_string = file_header+feed_rate_string+output_string + "M2\n"
        print output_string
    det = 1

total_pts = 2
cur_pt = 0
def points_init(*args):
    global total_pts
    global cur_pt
    global msg
    global v

    cur_pt = 0
    s.poll()
    points[cur_pt] = s.position[:s.axes]
    position = " ".join(["%-8.4f"] * s.axes)
    position = position % points[cur_pt][:s.axes]
    cur_pt += 1

    mode=v.get()
    if ((mode == "G0") or (mode == "G1")):
        total_pts = 2
    elif ((mode == "G2") or (mode == "G3")):
        total_pts = 3
    
    tmp = "%s: points(%d/%d)" % (mode, cur_pt, total_pts)
    tmp = tmp + "\n%s" % position 
    msg.set("%s" % tmp)

app = Tkinter.Tk(); app.wm_title('EMC2 Teach-In')
app.bind('<Destroy>',destory_bind)
app.protocol("WM_DELETE_WINDOW", save_quit)

world = Tkinter.IntVar(app)

button = Tkinter.Button(app, command=log, text='Learn', font=("helvetica", 14))
button.grid(row=0, sticky= W+E)


label2 = Tkinter.Label(app, font='fixed', anchor="w")
label2.config(relief= SUNKEN)
label2.grid(row=0,column=1, ipadx=2, ipady=2, columnspan = 11, sticky= W+E)


# TODO: 
MODES = [
    ("Rapid Motion", "G0"),
    ("Straight Feed", "G1"),
    ("Clockwise Arc", "G2"),
    ("Counterclockwise Arc", "G3"),
]

v = StringVar()
v.set("G1") # initialize
v.trace("w", points_init)

i = 1
for text, mode in MODES:
    b = Radiobutton(app, text=text, # indicatoron=0,
                    variable=v, value=mode)
    b.grid(row=i, column=0, sticky=W)
    i = i + 1

msg = StringVar()
label_msg = Tkinter.Label(app, font='fixed', textvariable=msg, anchor="nw", justify="left")
label_msg.grid (row=1, column=1, rowspan=(i-1),  columnspan=11, sticky=N+W)
msg.set ("Select motion type and click \"Learn\"")

label3 = Tkinter.Label(app, font='fixed', text="#3000=", anchor="w")
label3.grid(row=40,column=0, ipadx=2, ipady=2, sticky=E)

entry1 = Tkinter.Entry(app, font='fixed',width=10)
entry1.grid(row=40,column=1, sticky= W+E)
entry1.delete(0, END)
entry1.insert(0, "2000")
entry1.bind('<Return>', feedrate_press)

label4 = Tkinter.Label(app, font='fixed', text="#3001=", anchor="w")
label4.grid(row=40,column=2, ipadx=2, ipady=2, sticky=E)
entry2 = Tkinter.Entry(app,font='fixed',width=10)
entry2.grid(row=40,column=3, sticky= W+E)
entry2.delete(0, END)
entry2.insert(0, "2000")
entry2.bind('<Return>', feedrate_press)

label5 = Tkinter.Label(app, font='fixed', text="#3002=", anchor="w")
label5.grid(row=40,column=4, ipadx=2, ipady=2, sticky=E)
entry3 = Tkinter.Entry(app, font='fixed',width=10)
entry3.grid(row=40,column=5, sticky= W+E)
entry3.delete(0, END)
entry3.insert(0, "2000")
entry3.bind('<Return>', feedrate_press)

button1 = Tkinter.Button(app, command=ins_feed_3000, text='Insert F#3000', font=("helvetica", 14))
button1.grid(row=49, column=5, sticky= N+S+W+E)
button2 = Tkinter.Button(app, command=ins_feed_3001, text='Insert F#3001', font=("helvetica", 14))
button2.grid(row=50, column=5, sticky= N+S+W+E)
button3 = Tkinter.Button(app, command=ins_feed_3002, text='Insert F#3002', font=("helvetica", 14))
button3.grid(row=51, column=5, sticky= N+S+W+E)
button4 = Tkinter.Button(app, command=get_textbox_data, text='Apply', font=("helvetica", 14))
button4.grid(row=52, column=5, sticky= N+S+W+E)
button4.config(state=DISABLED)

button5 = Tkinter.Button(app, command=save_quit, text='Save Path', font=("helvetica", 14))
button5.grid(row=53, column=5, sticky= N+S+W+E)

text = Tkinter.Text(app)
 
text.grid(row=44,column=0,rowspan=10, columnspan=5, sticky = W+E)
update_feed_string()
update_textbox()
text.bind('<Button-1>', textbox_changed)

print "test teach-in"

show()
app.mainloop()

