headerdoc2html -j -o mCoupons/Documentation mCoupons/mCoupons.h     


gatherheaderdoc mCoupons/Documentation


sed -i.bak 's/<html><body>//g' mCoupons/Documentation/masterTOC.html
sed -i.bak 's|<\/body><\/html>||g' mCoupons/Documentation/masterTOC.html
sed -i.bak 's|<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN" "http://www.w3.org/TR/REC-html40/loose.dtd">||g' mCoupons/Documentation/masterTOC.html