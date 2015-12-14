Use our code to save yourself time on cross-platform, cross-device and cross OS version development and testing
# ios_module_Coupons
Coupons widget is intended to display a list of coupons provided by mobile application owner. When choosing an interest coupon in the list the detailed page will be opened.

Tags:

- title - widget name. Title is being displayed on navigation panel when widget is launched.
- colorskin - this is root tag to set up color scheme. Contains 5 elements (color[1-5]). Each widget may set colors for elements of the interface using the color scheme in any order, however generally color1 - background color, color3 - titles color, color4 - font color, color5 - date or price color.
- rss - RSS-feed URL.
- item - Root tag for elements describing coupon added manually. Includes sub tags title, description, url. Tags rss and item are mutually exclusive.
  - title - Coupon title
  - description - Title description
  - url - html-file url, created in generating content of details page on coupon manage-panel
