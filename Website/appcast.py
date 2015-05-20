import webapp2

class MainPage(webapp2.RequestHandler):
    def get(self):
        self.redirect("https://storage.googleapis.com/feeds-releases/appcast.xml")

app = webapp2.WSGIApplication([
    ('.*', MainPage),
], debug=True)