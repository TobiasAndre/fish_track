// Import and register all your controllers from the importmap via controllers/**/*_controller
import { application } from "controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
import "chartkick"
import "Chart.bundle"
eagerLoadControllersFrom("controllers", application)
