import { Controller } from "@hotwired/stimulus"
import AirDatepicker from "air-datepicker"
import "air-datepicker/air-datepicker.css"


export default class extends Controller {
  connect() {
    this.initDatepicker()
  }

  disconnect() {
    if (this.datepicker) {
      this.datepicker.destroy()
    }
  }

  initDatepicker() {
    const localeEn = {
      days: ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'],
      daysShort: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],
      daysMin: ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'],
      months: ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'],
      monthsShort: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'],
      today: 'Today',
      clear: 'Clear',
      dateFormat: 'MM/dd/yyyy',
      timeFormat: 'hh:mm aa',
      firstDay: 0
    }

    this.datepicker = new AirDatepicker(this.element, {
      autoClose: true,
      minDate: new Date(),
      locale: localeEn,
      position: 'top left'
    })
  }
}
