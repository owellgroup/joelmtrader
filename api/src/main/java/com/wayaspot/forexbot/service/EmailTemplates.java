package com.wayaspot.forexbot.service;

import java.util.List;
import java.util.Locale;

/** Responsive, inline-CSS HTML e-mail building blocks (works in Gmail / Outlook / Apple Mail). */
public final class EmailTemplates {
    private EmailTemplates() { }

    public static String money(Double v) {
        if (v == null) return "-";
        return String.format(Locale.US, "%s$%,.2f", v < 0 ? "-" : "", Math.abs(v));
    }

    public static String signed(Double v) {
        if (v == null) return "-";
        return String.format(Locale.US, "%s$%,.2f", v < 0 ? "-" : "+", Math.abs(v));
    }

    public static String color(Double v) {
        return v == null || v == 0 ? "#64748b" : (v > 0 ? "#059669" : "#dc2626");
    }

    public static String esc(String s) {
        if (s == null) return "";
        return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;");
    }

    public static String wrap(String brand, String logoUrl, String title, String subtitle, String body) {
        String logo = (logoUrl == null || logoUrl.isBlank())
                ? "<div style=\"font-size:22px;font-weight:800;color:#ffffff;letter-spacing:.5px\">" + esc(brand) + "</div>"
                : "<img src=\"" + esc(logoUrl) + "\" alt=\"" + esc(brand) + "\" height=\"48\" style=\"display:block;margin:0 auto;height:48px;border:0\">";
        return "<!doctype html><html><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"></head>"
                + "<body style=\"margin:0;padding:0;background:#f1f5f9;font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#0f172a\">"
                + "<table role=\"presentation\" width=\"100%\" cellspacing=\"0\" cellpadding=\"0\" style=\"background:#f1f5f9;padding:24px 12px\"><tr><td align=\"center\">"
                + "<table role=\"presentation\" width=\"640\" cellspacing=\"0\" cellpadding=\"0\" style=\"max-width:640px;width:100%;background:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(15,23,42,.08)\">"
                + "<tr><td align=\"center\" style=\"background:linear-gradient(135deg,#0f172a,#0e7c66);padding:28px 24px\">" + logo
                + "<div style=\"color:#ffffff;font-size:20px;font-weight:700;margin-top:14px\">" + esc(title) + "</div>"
                + "<div style=\"color:#a7f3d0;font-size:13px;margin-top:4px\">" + esc(subtitle) + "</div></td></tr>"
                + "<tr><td style=\"padding:24px\">" + body + "</td></tr>"
                + "<tr><td style=\"background:#f8fafc;padding:16px 24px;font-size:11px;color:#64748b;text-align:center\">"
                + "Automated message from " + esc(brand) + ". Trading leveraged instruments carries a high risk of loss; past performance does not guarantee future results."
                + "</td></tr></table></td></tr></table></body></html>";
    }

    public static String kpis(List<String[]> items) {
        StringBuilder sb = new StringBuilder("<table role=\"presentation\" width=\"100%\" cellspacing=\"8\" cellpadding=\"0\"><tr>");
        int i = 0;
        for (String[] it : items) {
            if (i > 0 && i % 2 == 0) sb.append("</tr><tr>");
            sb.append("<td width=\"50%\" style=\"background:#f8fafc;border:1px solid #e2e8f0;border-radius:12px;padding:14px\">")
                    .append("<div style=\"font-size:11px;color:#64748b;text-transform:uppercase;letter-spacing:.6px\">").append(esc(it[0])).append("</div>")
                    .append("<div style=\"font-size:22px;font-weight:800;margin-top:4px;color:").append(it.length > 2 ? it[2] : "#0f172a").append("\">")
                    .append(esc(it[1])).append("</div></td>");
            i++;
        }
        return sb.append("</tr></table>").toString();
    }

    public static String section(String title) {
        return "<div style=\"font-size:15px;font-weight:700;margin:22px 0 8px\">" + esc(title) + "</div>";
    }

    public static String table(List<String> headers, List<List<String>> rows) {
        StringBuilder sb = new StringBuilder("<div style=\"overflow-x:auto\"><table width=\"100%\" cellspacing=\"0\" cellpadding=\"0\" style=\"border-collapse:collapse;font-size:12px\"><tr>");
        for (String h : headers)
            sb.append("<th align=\"left\" style=\"padding:8px;border-bottom:2px solid #e2e8f0;color:#475569\">").append(esc(h)).append("</th>");
        sb.append("</tr>");
        for (List<String> r : rows) {
            sb.append("<tr>");
            for (String c : r) sb.append("<td style=\"padding:8px;border-bottom:1px solid #f1f5f9\">").append(c).append("</td>");
            sb.append("</tr>");
        }
        return sb.append("</table></div>").toString();
    }

    public static String badge(String text, String bg) {
        return "<span style=\"background:" + bg + ";color:#fff;border-radius:999px;padding:2px 9px;font-size:11px;font-weight:700\">" + esc(text) + "</span>";
    }
}
