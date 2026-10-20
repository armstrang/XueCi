package com.armstrang.xueci

import android.app.Activity
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.ConsumeParams
import com.android.billingclient.api.PendingPurchasesParams
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.PurchasesUpdatedListener
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams
import org.json.JSONArray
import org.json.JSONObject

/**
 * 护法: voluntary donations through Google Play Billing. The products are consumable one-time products that unlock
 * nothing; each finished purchase is consumed at once so it can be given again. Nothing is kept here: the app counts
 * donations itself (xc_dn). Off Google Play (the test APK from GitHub) the products are simply not found.
 */
class Donate(private val activity: Activity) : PurchasesUpdatedListener {
    private val client: BillingClient = BillingClient.newBuilder(activity)
        .setListener(this)
        .enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
        .build()
    private var details: Map<String, ProductDetails> = emptyMap()
    private var buying: ((String) -> Unit)? = null

    private fun connect(done: (Boolean) -> Unit) {
        if (client.isReady) {
            done(true)
            return
        }
        try {
            client.startConnection(object : BillingClientStateListener {
                override fun onBillingSetupFinished(result: BillingResult) {
                    done(result.responseCode == BillingClient.BillingResponseCode.OK)
                }

                override fun onBillingServiceDisconnected() {}
            })
        } catch (e: Exception) {
            done(false)
        }
    }

    /** {"ok":true,"items":[{"id","price"}],"done":n} (n = earlier purchases finished now), or {"ok":false} */
    fun products(ids: List<String>, done: (String) -> Unit) = connect { ok ->
        if (!ok) {
            done("{\"ok\":false}")
            return@connect
        }
        val params = QueryProductDetailsParams.newBuilder()
            .setProductList(
                ids.map {
                    QueryProductDetailsParams.Product.newBuilder()
                        .setProductId(it)
                        .setProductType(BillingClient.ProductType.INAPP)
                        .build()
                },
            )
            .build()
        client.queryProductDetailsAsync(params) { result, found ->
            val list: List<ProductDetails> =
                if (result.responseCode == BillingClient.BillingResponseCode.OK) found.productDetailsList else emptyList()
            details = list.associateBy { it.productId }
            sweep { n ->
                val items = JSONArray()
                for (id in ids) {
                    val pd = details[id] ?: continue
                    val price = pd.oneTimePurchaseOfferDetails?.formattedPrice ?: continue
                    items.put(JSONObject().put("id", id).put("price", price))
                }
                done(JSONObject().put("ok", items.length() > 0).put("items", items).put("done", n).toString())
            }
        }
    }

    /** purchases finished while the app was away (or still unconsumed): consumed now, counted */
    private fun sweep(done: (Int) -> Unit) {
        val params = QueryPurchasesParams.newBuilder().setProductType(BillingClient.ProductType.INAPP).build()
        client.queryPurchasesAsync(params) { result, purchases ->
            val paid = if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                purchases.filter { it.purchaseState == Purchase.PurchaseState.PURCHASED }
            } else {
                emptyList()
            }
            if (paid.isEmpty()) {
                done(0)
                return@queryPurchasesAsync
            }
            var left = paid.size
            var n = 0
            for (p in paid) {
                consume(p) { ok ->
                    if (ok) n++
                    if (--left == 0) done(n)
                }
            }
        }
    }

    private fun consume(p: Purchase, done: (Boolean) -> Unit) {
        val params = ConsumeParams.newBuilder().setPurchaseToken(p.purchaseToken).build()
        client.consumeAsync(params) { result, _ -> done(result.responseCode == BillingClient.BillingResponseCode.OK) }
    }

    /** ok | pending | cancel | error */
    fun buy(id: String, done: (String) -> Unit) = connect { ok ->
        val pd = details[id]
        if (!ok || pd == null) {
            done("error")
            return@connect
        }
        val flow = BillingFlowParams.newBuilder()
            .setProductDetailsParamsList(listOf(BillingFlowParams.ProductDetailsParams.newBuilder().setProductDetails(pd).build()))
            .build()
        buying = done
        val r = client.launchBillingFlow(activity, flow)
        if (r.responseCode != BillingClient.BillingResponseCode.OK) {
            buying = null
            done("error")
        }
    }

    override fun onPurchasesUpdated(result: BillingResult, purchases: MutableList<Purchase>?) {
        val done = buying ?: return
        buying = null
        when (result.responseCode) {
            BillingClient.BillingResponseCode.OK -> {
                val p = purchases?.firstOrNull()
                when {
                    p == null -> done("error")
                    p.purchaseState == Purchase.PurchaseState.PURCHASED -> consume(p) { done(if (it) "ok" else "pending") }
                    else -> done("pending")
                }
            }
            BillingClient.BillingResponseCode.USER_CANCELED -> done("cancel")
            BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED -> sweep { done(if (it > 0) "ok" else "error") }
            else -> done("error")
        }
    }

    fun end() {
        try {
            client.endConnection()
        } catch (_: Exception) {
        }
    }
}
