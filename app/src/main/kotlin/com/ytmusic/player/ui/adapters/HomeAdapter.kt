package com.ytmusic.player.ui.adapters

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.TextView
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.bumptech.glide.Glide
import com.ytmusic.player.R
import com.ytmusic.player.data.model.Section
import com.ytmusic.player.data.model.SectionItem
import com.ytmusic.player.util.loadImage

class HomeAdapter : RecyclerView.Adapter<HomeAdapter.SectionViewHolder>() {

    private var sections: List<Section> = emptyList()
    private var onItemClick: ((SectionItem) -> Unit)? = null

    fun submitList(list: List<Section>) {
        sections = list
        notifyDataSetChanged()
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): SectionViewHolder {
        val view = LayoutInflater.from(parent.context)
            .inflate(R.layout.item_section_row, parent, false)
        return SectionViewHolder(view)
    }

    override fun onBindViewHolder(holder: SectionViewHolder, position: Int) {
        holder.bind(sections[position])
    }

    override fun getItemCount(): Int = sections.size

    inner class SectionViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
        private val titleText: TextView = itemView.findViewById(R.id.section_title)
        private val itemsRecycler: RecyclerView = itemView.findViewById(R.id.section_items)
        private val sectionAdapter = SectionItemsAdapter()

        init {
            itemsRecycler.layoutManager = LinearLayoutManager(
                itemView.context,
                LinearLayoutManager.HORIZONTAL,
                false
            )
            itemsRecycler.adapter = sectionAdapter
            sectionAdapter.onItemClick = { item ->
                onItemClick?.invoke(item)
            }
        }

        fun bind(section: Section) {
            titleText.text = section.title
            sectionAdapter.submitList(section.items)
        }
    }
}

class SectionItemsAdapter : RecyclerView.Adapter<SectionItemsAdapter.ItemViewHolder>() {

    var onItemClick: ((SectionItem) -> Unit)? = null
    private var items: List<SectionItem> = emptyList()

    fun submitList(list: List<SectionItem>) {
        items = list
        notifyDataSetChanged()
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ItemViewHolder {
        val view = LayoutInflater.from(parent.context)
            .inflate(R.layout.item_section_card, parent, false)
        return ItemViewHolder(view)
    }

    override fun onBindViewHolder(holder: ItemViewHolder, position: Int) {
        holder.bind(items[position])
    }

    override fun getItemCount(): Int = items.size

    inner class ItemViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
        private val image: ImageView = itemView.findViewById(R.id.card_image)
        private val title: TextView = itemView.findViewById(R.id.card_title)
        private val subtitle: TextView = itemView.findViewById(R.id.card_subtitle)

        init {
            itemView.setOnClickListener {
                val pos = adapterPosition
                if (pos != RecyclerView.NO_POSITION) {
                    onItemClick?.invoke(items[pos])
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
