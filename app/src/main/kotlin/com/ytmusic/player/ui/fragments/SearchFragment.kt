package com.ytmusic.player.ui.fragments

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.EditText
import android.widget.ImageButton
import androidx.fragment.app.Fragment
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.ytmusic.player.R
import com.ytmusic.player.YTMusicApp
import com.ytmusic.player.ui.adapters.SearchAdapter
import kotlinx.coroutines.launch

class SearchFragment : Fragment() {

    private lateinit var searchInput: EditText
    private lateinit var searchButton: ImageButton
    private lateinit var recyclerView: RecyclerView
    private lateinit var adapter: SearchAdapter
    private lateinit var emptyView: View

    private val handler = Handler(Looper.getMainLooper())
    private var searchRunnable: Runnable? = null

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        return inflater.inflate(R.layout.fragment_search, container, false)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        searchInput = view.findViewById(R.id.search_input)
        searchButton = view.findViewById(R.id.search_button)
        recyclerView = view.findViewById(R.id.search_recycler)
        emptyView = view.findViewById(R.id.search_empty)

        adapter = SearchAdapter(requireContext())
        recyclerView.layoutManager = LinearLayoutManager(context)
        recyclerView.adapter = adapter

        searchButton.setOnClickListener { performSearch() }

        searchInput.setOnEditorActionListener { _, _, _ ->
            performSearch()
            true
        }
    }

    private fun performSearch() {
        val query = searchInput.text.toString().trim()
        if (query.isEmpty()) return

        searchRunnable?.let { handler.removeCallbacks(it) }
        searchRunnable = Runnable {
            lifecycleScope.launch {
                val repo = YTMusicApp.instance.musicRepository
                repo.getSearchResults(query).fold(
                    onSuccess = { items ->
                        if (items.isEmpty()) {
                            emptyView.visibility = View.VISIBLE
                            recyclerView.visibility = View.GONE
                        } else {
                            emptyView.visibility = View.GONE
                            recyclerView.visibility = View.VISIBLE
                            adapter.submitList(items)
                        }
                    },
                    onFailure = {
                        emptyView.visibility = View.VISIBLE
                    }
                )
            }
        }
        handler.postDelayed(searchRunnable, 300)
    }
}
