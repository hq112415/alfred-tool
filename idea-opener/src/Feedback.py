# author: Peter Okma
import xml.etree.ElementTree as et


class Feedback:
    """Feedback used by Alfred Script Filter"""

    def __init__(self):
        self.feedback = et.Element('items')

    def __repr__(self):
        return et.tostring(self.feedback).decode('utf-8')

    def add_item(self, title, subtitle="", arg="", valid="yes", autocomplete="", icon="icon.png"):
        item = et.SubElement(self.feedback, 'item', uid=str(len(self.feedback)),
                             arg=arg, valid=valid, autocomplete=autocomplete)
        _title = et.SubElement(item, 'title')
        _title.text = title
        _sub = et.SubElement(item, 'subtitle')
        _sub.text = subtitle
        _icon = et.SubElement(item, 'icon')
        _icon.text = icon

    def isEmpty(self):
        return len(self.feedback.findall(path="./")) == 0
