import json
import math
import random
import sys
from tkinter import *
from PIL import Image, ImageTk

def main():
    root = Tk()
    root.title("LA Quiz")

    imgfile = sys.argv[1]
    ansfile = sys.argv[2]
    debug_mode = False
    if len(sys.argv) > 3 and sys.argv[3] == "d":
        debug_mode = True

    raw_img = Image.open(imgfile)
    scale_factor = 1000.0 / float(raw_img.width)
    image = ImageTk.PhotoImage(
        raw_img.resize(
            (int(scale_factor * raw_img.width), int(scale_factor * raw_img.height)),
            Image.LANCZOS,
        )
    )

    canvas = Canvas(root, width=image.width(), height=image.height())
    canvas.pack()
    canvas.create_image(0, 0, anchor=NW, image=image)

    class QuizDriver:
        AWAITING_INPUT = 0
        GRADING_INPUT = 1
        def __init__(self, answers_json, debug_mode):
            with open(answers_json, "r") as answer_file:
                self.cities = json.loads(answer_file.read())["cities"]
            self.city_idx = 0
            random.shuffle(self.cities)
            self.state = QuizDriver.AWAITING_INPUT
            self.debug_mode = debug_mode
        def handle_click(self, event):
            root.title(self.cities[self.city_idx]["name"])
            canvas.delete("marker")
            xc, yc = event.x, event.y
            if self.state == QuizDriver.AWAITING_INPUT:
                self.state = QuizDriver.GRADING_INPUT
            else:
                if self.debug_mode:
                    canvas.create_text(xc, yc, text=f"({xc}, {yc})", fill="red", tags="marker")
                x = self.cities[self.city_idx]["x"]
                y = self.cities[self.city_idx]["y"]
                if math.sqrt(float((x-xc)*(x-xc)) + float((y-yc)*(y-yc))) < 20:
                    canvas.create_oval(x-5, y-5, x+5, y+5, fill="green", tags="marker")
                else:
                    canvas.create_oval(x-5, y-5, x+5, y+5, fill="red", tags="marker")
                self.state = QuizDriver.AWAITING_INPUT
                if self.city_idx < len(self.cities) - 1:
                    self.city_idx += 1
                else:
                    self.city_idx = 0
                    random.shuffle(self.cities)
    
    quiz = QuizDriver(ansfile, debug_mode)
    canvas.bind("<Button-1>", quiz.handle_click)

    root.mainloop()

if __name__ == "__main__":
    main()
