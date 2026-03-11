import { application } from "controllers/application"
import TabsController from "ruby_native/bridge/tabs_controller"
import FormController from "ruby_native/bridge/form_controller"
import PushController from "ruby_native/bridge/push_controller"
import MenuController from "ruby_native/bridge/menu_controller"
import SearchController from "ruby_native/bridge/search_controller"
import ButtonController from "ruby_native/bridge/button_controller"
import HapticController from "ruby_native/bridge/haptic_controller"

application.register("bridge--tabs", TabsController)
application.register("bridge--form", FormController)
application.register("bridge--push", PushController)
application.register("bridge--menu", MenuController)
application.register("bridge--search", SearchController)
application.register("bridge--button", ButtonController)
application.register("bridge--haptic", HapticController)
