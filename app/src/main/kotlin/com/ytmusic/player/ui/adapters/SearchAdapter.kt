package com.ytmusic.player.ui.adapters

import android.content.Context
import android.content.Intent
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.TextView
import androidx.recyclerview.widget.RecyclerView
import com.ytmusic.player.R
import com.ytmusic.player.data.model.ItemType
import com.ytmusic.player.data.model.SectionItem
import com.ytmusic.player.data.repository.MusicRepository
import com.ytmusic.player.ui.player.PlayerActivity
import com.ytmusic.player.util.loadImage
import kotlinx.coroutines.*

class SearchAdapter(private val context: Context) : RecyclerView.Adapter<SearchAdapter.ViewHolder>() {

    private var items: List<SectionItem> = emptyList()

    fun submitList(list: List<SectionItem>) {
        items = list
        notifyDataSetChanged()
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val view = LayoutInflater.from(parent.context)
            .inflate(R.layout.item_track, parent, false)
        return ViewHolder(view)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        holder.bind(items[position])
    }

    override fun getItemCount(): Int = items.size

    inner class ViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
        private val image: ImageView = itemView.findViewById(R.id.item_image)
        private val title: TextView = itemView.findViewById(R.id.item_title)
        private val subtitle: TextView = itemView.findViewById(R.id.item_subtitle)

        init {
            itemView.setOnClickListener {
                val pos = adapterPosition
                if (pos != RecyclerView.NO_POSITION) {
                    val item = items[pos]
                    if (item.videoId != null) {
                        val intent = Intent(context, PlayerActivity::class.java).apply {
                            putExtra("video_id", item.videoId)
                            putExtra("title", item.title)
                            putExtra("artist", item.subtitle)
                        }
                        context.startActivity(intent)
                    }
                }
            }
        }

        fun bind(item: SectionItem) {
            title.text = item.title
            subtitle.text = item.subtitle
            subtitle.visibility = if (item.subtitle != null) View.VISIBLE else View.GONE
            loadImage(item.thumbnailUrl, image, R.drawable.ic_placeholder)
        }
    }
}
