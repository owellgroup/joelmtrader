package com.wayaspot.forexbot.service;

import com.wayaspot.forexbot.entity.Trade;

import java.util.*;

/** Aggregates a list of CLOSED trades. */
public class TradeStats {
    public int trades, wins, losses;
    public double net, grossWin, grossLoss, best, worst;
    public final Map<String, double[]> bySymbol = new TreeMap<>();   // [trades, wins, net]

    public static TradeStats of(List<Trade> closed) {
        TradeStats s = new TradeStats();
        for (Trade t : closed) {
            double n = t.getNetProfit() == null ? 0 : t.getNetProfit();
            s.trades++;
            s.net += n;
            if (n > 0) { s.wins++; s.grossWin += n; } else if (n < 0) { s.losses++; s.grossLoss += -n; }
            s.best = Math.max(s.best, n);
            s.worst = Math.min(s.worst, n);
            double[] a = s.bySymbol.computeIfAbsent(t.getSymbol() == null ? "?" : t.getSymbol(), k -> new double[3]);
            a[0]++;
            if (n > 0) a[1]++;
            a[2] += n;
        }
        return s;
    }

    public double winRate() { return trades == 0 ? 0 : wins * 100.0 / trades; }
    public double profitFactor() { return grossLoss == 0 ? (grossWin > 0 ? 99 : 0) : grossWin / grossLoss; }
    public double avgWin() { return wins == 0 ? 0 : grossWin / wins; }
    public double avgLoss() { return losses == 0 ? 0 : -grossLoss / losses; }

    public Map<String, Object> toMap() {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("trades", trades);
        m.put("wins", wins);
        m.put("losses", losses);
        m.put("winRate", round(winRate()));
        m.put("netProfit", round(net));
        m.put("profitFactor", round(profitFactor()));
        m.put("avgWin", round(avgWin()));
        m.put("avgLoss", round(avgLoss()));
        m.put("best", round(best));
        m.put("worst", round(worst));
        List<Map<String, Object>> sym = new ArrayList<>();
        bySymbol.forEach((k, v) -> {
            Map<String, Object> e = new LinkedHashMap<>();
            e.put("symbol", k);
            e.put("trades", (int) v[0]);
            e.put("wins", (int) v[1]);
            e.put("net", round(v[2]));
            sym.add(e);
        });
        m.put("bySymbol", sym);
        return m;
    }

    private static double round(double v) { return Math.round(v * 100.0) / 100.0; }
}
